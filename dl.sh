#!/bin/bash
set -o pipefail
LOG_FILE="download_log.txt"
MAX_RETRIES=3

echo "====================================="
echo "   Direct Cloud Uploader to S3   "
echo "====================================="

# Check for dependencies
if ! command -v curl &> /dev/null; then
    echo "Error: curl is not installed. Please install it first."
    exit 1
fi

if ! command -v s5cmd &> /dev/null; then
    echo "Error: s5cmd is not installed. Please install it first."
    exit 1
fi

# Get configuration from the user
read -p "Enter your S3 bucket name: " BUCKET
read -p "Enter your prefix (e.g., models): " PREFIX
read -p "Enter your S3 endpoint URL (default: https://t3.storage.dev): " ENDPOINT
if [ -z "$ENDPOINT" ]; then ENDPOINT="https://t3.storage.dev"; fi

echo "====================================="
echo "1. Hugging Face (Model or Dataset)"
echo "2. Multiple Web URLs (Paste list)"
echo "3. Exit"
read -p "Choose an option (1/2/3): " CHOICE

if [ "$CHOICE" == "1" ]; then
    read -p "Enter Hugging Face repo: " REPO
    REPO=${REPO#https://huggingface.co/}
    read -p "Is this a 'model' or a 'dataset'? [model]: " TYPE
    if [ -z "$TYPE" ]; then TYPE="model"; fi

    echo "Fetching file list from Hugging Face..."
    API="https://huggingface.co/api/${TYPE}s/${REPO}"
    JSON=$(curl -s "$API")
    FILES=$(echo "$JSON" | grep -oP '"rfilename":"\K[^"]+')

    if [ -z "$FILES" ]; then
        echo "No files found, or repo does not exist. Check the name and try again."
        exit 1
    fi

    for FILE in $FILES; do
        S3_PATH="s3://${BUCKET}/${PREFIX}/${REPO//\//--}/${FILE}"
        URL="https://huggingface.co/${REPO}/resolve/main/${FILE}"

        # 1. Get Hugging Face file size (in bytes)
        if [ -n "$HF_TOKEN" ]; then
            HF_SIZE=$(curl -sIL -H "Authorization: Bearer $HF_TOKEN" "$URL" | grep -i "content-length" | tail -1 | awk '{print $2}' | tr -d '\r')
        else
            HF_SIZE=$(curl -sIL "$URL" | grep -i "content-length" | tail -1 | awk '{print $2}' | tr -d '\r')
        fi
        if [ -z "$HF_SIZE" ]; then HF_SIZE=0; fi

        # 2. Get S3 file size (if exists)
        S3_SIZE=$(s5cmd --endpoint-url $ENDPOINT ls "$S3_PATH" 2>/dev/null | awk '{print $3}')
        if [ -z "$S3_SIZE" ]; then S3_SIZE=0; fi

        # 3. Compare sizes
        if [ "$S3_SIZE" == "$HF_SIZE" ] && [ "$HF_SIZE" != "0" ]; then
            echo "Skipping $FILE (sizes match: $S3_SIZE bytes)"
            continue
        elif [ "$S3_SIZE" != "0" ]; then
            echo "Partial file found for $FILE (S3: $S3_SIZE bytes, HF: $HF_SIZE bytes). Deleting and re-downloading..."
            s5cmd --endpoint-url $ENDPOINT rm "$S3_PATH" > /dev/null 2>&1
        fi

        echo "Streaming: $FILE ($HF_SIZE bytes)"
        SUCCESS=0
        for attempt in $(seq 1 $MAX_RETRIES); do
            if [ -n "$HF_TOKEN" ]; then
                curl -f#L -H "Authorization: Bearer $HF_TOKEN" "$URL" | s5cmd --endpoint-url $ENDPOINT pipe "$S3_PATH"
            else
                curl -f#L "$URL" | s5cmd --endpoint-url $ENDPOINT pipe "$S3_PATH"
            fi

            if [ $? -eq 0 ]; then
                SUCCESS=1
                break
            fi
            echo "Attempt $attempt failed. Retrying in 5 seconds..."
            sleep 5
        done

        if [ $SUCCESS -eq 1 ]; then
            echo "$(date +'%Y-%m-%d %H:%M:%S') - SUCCESS: $FILE" >> $LOG_FILE
        else
            echo "$(date +'%Y-%m-%d %H:%M:%S') - FAILED: $FILE" >> $LOG_FILE
            echo "ERROR: Could not download $FILE after $MAX_RETRIES attempts."
        fi
    done

elif [ "$CHOICE" == "2" ]; then
    echo "Paste your URLs below, one per line."
    echo "When you are finished, press ENTER on an empty line:"
    URLS=()
    while read -r line; do
        if [ -z "$line" ]; then
            break
        fi
        URLS+=("$line")
    done

    for URL in "${URLS[@]}"; do
        DEFAULT_NAME=${URL##*/}
        DEFAULT_NAME=${DEFAULT_NAME%%\?*}
        if [ -z "$DEFAULT_NAME" ]; then
            DEFAULT_NAME="downloaded_file"
        fi

        read -p "Auto-detected name is '$DEFAULT_NAME'. Press Enter to keep it, or type a new name: " USER_NAME
        if [ -z "$USER_NAME" ]; then
            FILENAME="$DEFAULT_NAME"
        else
            FILENAME="$USER_NAME"
        fi

        S3_PATH="s3://${BUCKET}/${PREFIX}/${FILENAME}"

        # 1. Get source file size
        HF_SIZE=$(curl -sIL "$URL" | grep -i "content-length" | tail -1 | awk '{print $2}' | tr -d '\r')
        if [ -z "$HF_SIZE" ]; then HF_SIZE=0; fi

        # 2. Get S3 file size
        S3_SIZE=$(s5cmd --endpoint-url $ENDPOINT ls "$S3_PATH" 2>/dev/null | awk '{print $3}')
        if [ -z "$S3_SIZE" ]; then S3_SIZE=0; fi

        # 3. Compare sizes
        if [ "$S3_SIZE" == "$HF_SIZE" ] && [ "$HF_SIZE" != "0" ]; then
            echo "Skipping $FILENAME (sizes match: $S3_SIZE bytes)"
            continue
        elif [ "$S3_SIZE" != "0" ]; then
            echo "Partial file found for $FILENAME (S3: $S3_SIZE bytes, Source: $HF_SIZE bytes). Deleting and re-downloading..."
            s5cmd --endpoint-url $ENDPOINT rm "$S3_PATH" > /dev/null 2>&1
        fi

        echo "----------------------------------------"
        echo "Streaming: $URL"
        echo "Saving as: $FILENAME"
        SUCCESS=0
        for attempt in $(seq 1 $MAX_RETRIES); do
            curl -f#L "$URL" | s5cmd --endpoint-url $ENDPOINT pipe "$S3_PATH"

            if [ $? -eq 0 ]; then
                SUCCESS=1
                break
            fi
            echo "Attempt $attempt failed. Retrying in 5 seconds..."
            sleep 5
        done

        if [ $SUCCESS -eq 1 ]; then
            echo "$(date +'%Y-%m-%d %H:%M:%S') - SUCCESS: $FILENAME" >> $LOG_FILE
            echo "Finished: $FILENAME"
        else
            echo "$(date +'%Y-%m-%d %H:%M:%S') - FAILED: $FILENAME" >> $LOG_FILE
            echo "ERROR: Could not download $FILENAME after $MAX_RETRIES attempts."
        fi
        echo "----------------------------------------"
    done

elif [ "$CHOICE" == "3" ]; then
    echo "Goodbye!"
else
    echo "Invalid choice."
fi

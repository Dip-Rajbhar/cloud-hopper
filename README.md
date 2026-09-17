# cloud-hopper
Stream files directly from Hugging Face or any URL to S3-compatible storage (Tigris, Cloudflare R2, Backblaze B2, AWS S3) without using any local disk space. Auto-resumes, skips complete files, re-downloads partial ones. Built for mobile and low-storage environments.
## 🎯 Why Use This?

Downloading large models/files (100GB+) is painful when you don't have a big hard drive.

**Common problems:**
- **Cloud terminals** – free, but often have strict time limits, small persistent storage, and temporary disks that get wiped.
- **Mobile phones** – slow downloads, limited storage, and huge data usage.
- **Old laptops** – no room for a massive model.

**The solution:**
This script uses the massive internet connection of cloud servers to download files from Hugging Face and stream them **directly** into your S3-compatible bucket. Your device never touches the file. You just control it from a terminal.

Think of it as a **pipe** from the source to your cloud storage.

---

## ✨ Features

- **No local disk used** – files stream directly from source to your bucket.
- **Auto-resume** – checks your bucket before downloading. Skips complete files, re-downloads partial ones.
- **Retry logic** – if a download fails, it tries again up to 3 times.
- **Hugging Face support** – download entire model or dataset repos with one command.
- **Any URL support** – paste a list of direct links and it downloads them one by one.
- **Progress bars** – see exactly how much has been transferred.
- **Works with any S3 provider** – any S3-compatible object storage service will work.

---

## 🔧 Full Setup Guide

Follow these steps **one by one**. No prior experience needed.

### Step 1: Open a Cloud Terminal

You need a cloud terminal with a fast internet connection. Most cloud providers offer a free browser-based terminal (often called "Cloud Shell" or "Codespaces").

**General steps:**
1. Find a free cloud terminal service from your preferred provider.
2. Sign in with an account.
3. Wait for the terminal to open.

### Step 2: Install s5cmd

Copy and paste this **one command** into your terminal and press Enter:

```bash
curl -L https://github.com/peak/s5cmd/releases/download/v2.2.0/s5cmd_2.2.0_Linux-64bit.tar.gz | tar xvz -C /tmp && sudo mv /tmp/s5cmd /usr/local/bin/s5cmd
```
###Step 3: Set Your S3 Credentials

You need an S3-compatible storage provider. Many offer free tiers, but check their pricing and limits before uploading huge files.

Once you have your keys, set them in the terminal (replace with your actual keys):

```bash
export AWS_ACCESS_KEY_ID=your_access_key
```
```bash
export AWS_SECRET_ACCESS_KEY=your_secret_key
```
###Step 4: Download the Script

Save the dl.sh script to your machine. You can copy it from this repository, or paste it directly into your terminal using cat << 'EOF' > dl.sh ... EOF.

Once saved, make it executable by running:

```bash
chmod +x dl.sh
```
###Step 5: Run the Script

```bash
bash dl.sh
```

Follow the prompts:

1. Enter your S3 bucket name
2. Enter your prefix (e.g., models)
3. Enter your S3 endpoint URL
4. Choose Option 1 (Hugging Face) or Option 2 (Web URLs)
5. Wait for the progress bars

---

🚀 Usage Examples

Example 1: Download a Small Model

```bash
bash dl.sh
```

· Bucket: your-bucket-name
· Prefix: models
· Endpoint: https://your-s3-endpoint.com
· Option: 1
· Repo: username/model-name
· Type: model

Result: All files from the repo are streamed to s3://your-bucket-name/models/username--model-name/

Example 2: Download a Large Model (Multi-part)

```bash
bash dl.sh
```

· Bucket: your-bucket-name
· Prefix: models
· Endpoint: https://your-s3-endpoint.com
· Option: 1
· Repo: creator/large-model
· Type: model

Result: All weight files plus config files are streamed to s3://your-bucket-name/models/creator--large-model/

Example 3: Download Any File from the Web

```bash
bash dl.sh
```

· Bucket: your-bucket-name
· Prefix: models
· Endpoint: https://your-s3-endpoint.com
· Option: 2
· Paste URL: https://example.com/my-file.zip
· Filename: Press Enter to keep my-file.zip, or type a new name

Result: The file is streamed to s3://your-bucket-name/models/my-file.zip

Example 4: Download Multiple Files from the Web

```bash
bash dl.sh
```

· Option: 2
· Paste these URLs one per line:
  ```
  https://example.com/file1.zip
  https://example.com/file2.iso
  https://example.com/file3.tar.gz
  ```
· Press Enter on an empty line to finish
· Press Enter for each file to keep the auto-detected names

Result: All three files are streamed to your bucket, one by one.

---

⚠️ Important Notes

· Never share your credentials. Anyone with your keys can access your entire bucket.
· Respect model licenses. Some models have custom licenses. Check the model card before sharing.
· Storage costs money. A 200GB model will cost you on most providers. Check your provider's pricing.
· Use tmux for long downloads. If your connection drops, the download stops. Run tmux new -s download before bash dl.sh, then detach with Ctrl+B then D. The download continues in the background.
· Free tiers have limits. Cloud terminals often have weekly time limits or small disk space. This script bypasses disk limits but not usage limits.
· Gated models need a token. Set HF_TOKEN before running the script, otherwise you'll get a 401 error.
· Partial files are handled. If a download is interrupted, the script will detect a size mismatch and re-download that file from scratch.

---

🛠️ Troubleshooting

Error Solution
command not found: s5cmd Install s5cmd (see Step 2 above).
NoCredentialProviders Set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY.
403 Forbidden Check your credentials, or the file may be gated (set HF_TOKEN).
Download is very slow Try switching your S3 endpoint or your cloud terminal provider.
File skipped but incomplete This is handled by size checking. If it still happens, delete the file from your bucket and run again.
Shell keeps resetting Use tmux to keep the download running in the background.
Running out of disk This script doesn't use your disk. If you're running out, you're saving files locally somewhere else.

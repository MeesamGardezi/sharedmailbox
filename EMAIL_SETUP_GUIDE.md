# Email Account Setup Guide

This guide will help you connect your email accounts (Gmail, Outlook, cPanel, etc.) to SharedBox.

## 📧 Supported Email Providers

- **Gmail** (Google Workspace)
- **Outlook** (Office 365)
- **cPanel Email** (Custom domains)
- **Any IMAP-enabled email**

---

## 🔐 Gmail Setup

### Step 1: Enable IMAP in Gmail
1. Go to Gmail Settings (gear icon → See all settings)
2. Click the **Forwarding and POP/IMAP** tab
3. Enable **IMAP access**
4. Click **Save Changes**

### Step 2: Create an App Password
Since Gmail uses 2-factor authentication, you need an app password:

1. Go to your [Google Account](https://myaccount.google.com/)
2. Navigate to **Security**
3. Under "Signing in to Google", select **2-Step Verification** (enable if not already)
4. Scroll down and select **App passwords**
5. Select app: **Mail**
6. Select device: **Other (Custom name)** → Enter "SharedBox"
7. Click **Generate**
8. **Copy the 16-character password** (you'll use this in SharedBox)

### Step 3: Add to SharedBox
In SharedBox → Email Accounts → Add Email Account:

- **Provider**: Gmail
- **Account Name**: My Gmail Account (or any name)
- **Email Address**: your-email@gmail.com
- **IMAP Host**: imap.gmail.com (auto-filled)
- **IMAP Port**: 993 (auto-filled)
- **Email Username**: your-email@gmail.com
- **Password**: [Paste the 16-character app password]
- **Use TLS/SSL**: ✅ Checked

---

## 📨 Outlook / Office 365 Setup

### Step 1: Enable IMAP (if not already enabled)
1. Sign in to Outlook.com
2. Go to Settings → View all Outlook settings
3. Go to Mail → Sync email
4. Ensure IMAP is enabled

### Step 2: Add to SharedBox
In SharedBox → Email Accounts → Add Email Account:

- **Provider**: Outlook
- **Account Name**: My Outlook Account
- **Email Address**: your-email@outlook.com
- **IMAP Host**: outlook.office365.com (auto-filled)
- **IMAP Port**: 993 (auto-filled)
- **Email Username**: your-email@outlook.com
- **Password**: Your Outlook password
- **Use TLS/SSL**: ✅ Checked

**Note**: If you have 2FA enabled, you may need to create an app password:
1. Go to [Microsoft Account Security](https://account.microsoft.com/security)
2. Select **Advanced security options**
3. Under **App passwords**, select **Create a new app password**

---

## 🌐 cPanel Email Setup

### Finding Your cPanel Email Settings

#### Method 1: Through cPanel
1. Log in to your cPanel account
2. Go to **Email Accounts**
3. Find your email account and click **Connect Devices**
4. Look for **Mail Client Manual Settings**

You'll see something like:
```
Incoming Server: mail.yourdomain.com
IMAP Port: 993
Username: you@yourdomain.com
```

#### Method 2: Common cPanel Settings
Most cPanel emails use these settings:

- **IMAP Host**: `mail.yourdomain.com` (replace with your domain)
- **IMAP Port**: `993`
- **Username**: Your full email address (e.g., `you@yourdomain.com`)
- **SSL/TLS**: Enabled

### Step-by-Step for cPanel

1. **Find your mail server hostname**:
   - Usually `mail.yourdomain.com`
   - Or `server.yourhostingprovider.com`
   - Check your hosting provider's documentation

2. **Add to SharedBox**:
   - **Provider**: cPanel / Other
   - **Account Name**: My Business Email
   - **Email Address**: you@yourdomain.com
   - **IMAP Host**: mail.yourdomain.com
   - **IMAP Port**: 993
   - **Email Username**: you@yourdomain.com (full email address)
   - **Password**: Your email password
   - **Use TLS/SSL**: ✅ Checked

### Common cPanel Hosting Providers

| Provider | IMAP Host Format |
|----------|------------------|
| **Bluehost** | `mail.yourdomain.com` or `box####.bluehost.com` |
| **HostGator** | `mail.yourdomain.com` or `gator####.hostgator.com` |
| **GoDaddy** | `mail.yourdomain.com` |
| **SiteGround** | `mail.yourdomain.com` |
| **Namecheap** | `mail.privateemail.com` |

---

## 🔧 Troubleshooting

### "Authentication Failed"
- ✅ Double-check your email and password
- ✅ For Gmail: Make sure you're using the app password, not your regular password
- ✅ For Outlook with 2FA: Use an app password
- ✅ Verify IMAP is enabled in your email settings

### "Connection Timeout"
- ✅ Check the IMAP host address
- ✅ Verify the port (usually 993 for SSL)
- ✅ Ensure SSL/TLS is enabled
- ✅ Check if your hosting provider blocks IMAP connections

### "SSL Certificate Error"
- ✅ Make sure "Use TLS/SSL" is checked
- ✅ Try port 993 (SSL) instead of 143 (non-SSL)

### cPanel Specific Issues
- ✅ Use your **full email address** as the username
- ✅ Contact your hosting provider for exact IMAP settings
- ✅ Some hosts require you to enable IMAP in cPanel first

---

## 📝 Quick Reference

### Gmail
```
Host: imap.gmail.com
Port: 993
SSL: Yes
Username: your-email@gmail.com
Password: App Password (16 characters)
```

### Outlook
```
Host: outlook.office365.com
Port: 993
SSL: Yes
Username: your-email@outlook.com
Password: Your Outlook password
```

### cPanel
```
Host: mail.yourdomain.com
Port: 993
SSL: Yes
Username: you@yourdomain.com
Password: Your email password
```

---

## 🔒 Security Best Practices

1. **Use App Passwords** for Gmail and Outlook (when 2FA is enabled)
2. **Enable SSL/TLS** for all connections
3. **Use strong passwords** for your email accounts
4. **Regularly review** connected accounts
5. **Remove unused accounts** from SharedBox

---

## ✅ Testing Your Connection

After adding an account:
1. Click the **Test Connection** button (coming soon)
2. Or navigate to **Inbox** and click **Refresh**
3. Emails should start appearing

---

## 🆘 Still Having Issues?

1. Check your email provider's documentation for IMAP settings
2. Contact your hosting provider's support
3. Verify your email account is active and not suspended
4. Check if your firewall is blocking port 993

---

**Need help with a specific provider?** Check their official IMAP setup documentation or contact their support team.

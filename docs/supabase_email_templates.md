# Supabase Email Identity & Templates

There are two separate settings:

1. **Email content** — Product, developer and support details shown inside the email.
2. **Sender identity** — The From name/address, configured through Custom SMTP.

---

## A. Email content — do this now

In Supabase Dashboard open:

**Authentication → Emails → Templates**

Depending on the Dashboard layout, this may appear as:

**Authentication → Email Templates**

### Confirm signup

Open **Confirm signup** and set:

**Subject**

```text
Verify your Prescription Scanner account
```

**Body**

```html
<div style="font-family:Arial,sans-serif;max-width:560px;margin:auto;padding:24px;color:#172033">
  <h2 style="margin:0 0 12px;color:#0F766E">Verify your email</h2>
  <p>Thanks for creating a Prescription Scanner account.</p>
  <p>Please verify your email address to activate secure prescription scanning.</p>
  <p style="margin:28px 0">
    <a href="{{ .ConfirmationURL }}"
       style="background:#0F766E;color:#ffffff;text-decoration:none;padding:13px 20px;border-radius:10px;font-weight:bold">
      Verify email address
    </a>
  </p>
  <p style="font-size:13px;color:#68758A">If you did not create this account, you can safely ignore this email.</p>
  <hr style="border:0;border-top:1px solid #DFE7EE;margin:24px 0">
  <p style="font-size:12px;color:#68758A;line-height:1.5">
    Prescription Scanner is an AI transcription tool and does not provide medical advice.<br>
    Developed by Keshab Studios<br>
    Support: <a href="mailto:keshabsarkar2018@gmail.com">keshabsarkar2018@gmail.com</a>
  </p>
</div>
```

Click **Save**.

### Reset password / Recovery

Open **Reset password** or **Recovery** and set:

**Subject**

```text
Reset your Prescription Scanner password
```

**Body**

```html
<div style="font-family:Arial,sans-serif;max-width:560px;margin:auto;padding:24px;color:#172033">
  <h2 style="margin:0 0 12px;color:#0F766E">Reset your password</h2>
  <p>We received a request to reset your Prescription Scanner password.</p>
  <p style="margin:28px 0">
    <a href="{{ .ConfirmationURL }}"
       style="background:#0F766E;color:#ffffff;text-decoration:none;padding:13px 20px;border-radius:10px;font-weight:bold">
      Choose a new password
    </a>
  </p>
  <p style="font-size:13px;color:#68758A">If you did not request this, ignore the email and your password will remain unchanged.</p>
  <hr style="border:0;border-top:1px solid #DFE7EE;margin:24px 0">
  <p style="font-size:12px;color:#68758A;line-height:1.5">
    Prescription Scanner · Keshab Studios<br>
    Support: <a href="mailto:keshabsarkar2018@gmail.com">keshabsarkar2018@gmail.com</a>
  </p>
</div>
```

Click **Save**.

Do not replace `{{ .ConfirmationURL }}`. Supabase inserts the secure verification/recovery link there.

---

## B. Sender name and sender email — production setup

To make the email appear as coming from **Keshab Studios**, open:

**Authentication → Settings → SMTP Settings**

or, depending on Dashboard layout:

**Project Settings → Authentication → SMTP**

Enable **Custom SMTP** and configure:

```text
Sender name: Keshab Studios
Sender email: a verified sender address
SMTP host: supplied by your email provider
SMTP port: supplied by your email provider
SMTP user: supplied by your email provider
SMTP password: supplied by your email provider
```

Recommended production providers include Resend, Brevo, Postmark, Amazon SES or SendGrid. A verified custom-domain sender such as `no-reply@yourdomain.com` is better for production deliverability than a personal Gmail address.

For development, Supabase's default SMTP can be used for limited testing, but it is not intended for a public production launch and may only send to authorized team addresses.

Never share an SMTP password or Google App Password in chat, Flutter source or Git.

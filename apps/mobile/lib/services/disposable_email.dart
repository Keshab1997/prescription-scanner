/// Disposable / temporary email provider domains that are not allowed to
/// register or sign in.
///
/// Kept lowercase; matching is case-insensitive. The list covers the most
/// common temp-mail services (mailinator, yopmail, guerrillamail,
/// 10minutemail, throwaway services, etc.) and can be extended freely.
const Set<String> kDisposableEmailDomains = {
  '10minutemail.com',
  '1secmail.com',
  '1secmail.net',
  '1secmail.org',
  'discard.email',
  'discardmail.com',
  'dispostable.com',
  'dropmail.me',
  'emailfake.com',
  'emailnator.com',
  'emailondeck.com',
  'emltmp.com',
  'fakeinbox.com',
  'fake-mail.net',
  'fakemailgenerator.com',
  'getnada.com',
  'guerrillamail.biz',
  'guerrillamail.com',
  'guerrillamail.de',
  'guerrillamail.info',
  'guerrillamail.net',
  'guerrillamail.org',
  'inboxkitten.com',
  'mailcatch.com',
  'maildrop.cc',
  'mailgolem.com',
  'mailinator.com',
  'mailinator.net',
  'mailnesia.com',
  'mailtemp.net',
  'mailsac.com',
  'mintemail.com',
  'moakt.com',
  'mohmal.com',
  'mohmal.in',
  'mytemp.email',
  'nada.email',
  'owlymail.com',
  'sharklasers.com',
  'spam4.me',
  'spambox.us',
  'spamgourmet.com',
  'temp-mail.io',
  'temp-mail.org',
  'temp-mail.top',
  'tempmail.com',
  'tempmail.dev',
  'tempmail.net',
  'tempmail.org',
  'tempmailo.com',
  'tempinbox.com',
  'temps-mail.com',
  'throwaway.email',
  'throwawaymail.com',
  'tmpmail.org',
  'trashmail.com',
  'trashmail.de',
  'yopmail.com',
  'yopmail.fr',
  'yopmail.net',
};

/// Returns a user-facing error message when [email] uses a disposable /
/// temporary mail domain; returns null when the address is allowed.
String? disposableEmailError(String email) {
  final at = email.lastIndexOf('@');
  // Empty local part (e.g. '@mailinator.com') is not a valid address; let
  // Firebase report it as invalid instead of treating it as disposable.
  if (at <= 0 || at == email.length - 1) return null;
  final domain = email.substring(at + 1).trim().toLowerCase();
  if (domain.isEmpty) return null;
  if (kDisposableEmailDomains.contains(domain)) {
    return 'This email provider (temporary/disposable mail) is not allowed. '
        'Please use a real email address.';
  }
  return null;
}

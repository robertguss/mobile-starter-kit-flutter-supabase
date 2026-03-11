///
/// Generated file. Do not edit.
///
// coverage:ignore-file
// ignore_for_file: type=lint, unused_import
// dart format off

part of 'strings.g.dart';

// Path: <root>
typedef TranslationsEn = Translations; // ignore: unused_element
class Translations with BaseTranslations<AppLocale, Translations> {
	/// Returns the current translations of the given [context].
	///
	/// Usage:
	/// final t = Translations.of(context);
	static Translations of(BuildContext context) => InheritedLocaleData.of<AppLocale, Translations>(context).translations;

	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	Translations({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = meta ?? TranslationMetadata(
		    locale: AppLocale.en,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ) {
		$meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <en>.
	@override final TranslationMetadata<AppLocale, Translations> $meta;

	/// Access flat map
	dynamic operator[](String key) => $meta.getTranslation(key);

	late final Translations _root = this; // ignore: unused_field

	Translations $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => Translations(meta: meta ?? this.$meta);

	// Translations
	late final TranslationsAppEn app = TranslationsAppEn.internal(_root);
	late final TranslationsAuthEn auth = TranslationsAuthEn.internal(_root);
	late final TranslationsNotesEn notes = TranslationsNotesEn.internal(_root);
	late final TranslationsSettingsEn settings = TranslationsSettingsEn.internal(_root);
	late final TranslationsSubscriptionEn subscription = TranslationsSubscriptionEn.internal(_root);
	late final TranslationsCommonEn common = TranslationsCommonEn.internal(_root);
}

// Path: app
class TranslationsAppEn {
	TranslationsAppEn.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Flutter Supabase Starter'
	String get title => 'Flutter Supabase Starter';
}

// Path: auth
class TranslationsAuthEn {
	TranslationsAuthEn.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Email'
	String get emailLabel => 'Email';

	/// en: 'you@example.com'
	String get emailHint => 'you@example.com';

	/// en: 'Enter a valid email address.'
	String get invalidEmailError => 'Enter a valid email address.';

	/// en: 'We could not send a code right now.'
	String get sendOtpError => 'We could not send a code right now.';

	/// en: 'Send code'
	String get sendOtp => 'Send code';

	/// en: 'Verification code'
	String get otpLabel => 'Verification code';

	/// en: '123456'
	String get otpHint => '123456';

	/// en: 'That code is invalid or expired.'
	String get otpError => 'That code is invalid or expired.';

	/// en: 'Verify code'
	String get verifyOtp => 'Verify code';

	/// en: 'Resend code'
	String get resendOtp => 'Resend code';

	/// en: 'Resend in 30s'
	String get resendCooldown => 'Resend in 30s';

	/// en: 'Sign out'
	String get signOut => 'Sign out';
}

// Path: notes
class TranslationsNotesEn {
	TranslationsNotesEn.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Notes'
	String get title => 'Notes';

	/// en: 'No notes yet.'
	String get emptyState => 'No notes yet.';

	/// en: 'Untitled note'
	String get newNoteTitle => 'Untitled note';

	/// en: 'New note'
	String get create => 'New note';

	/// en: 'Title'
	String get titleLabel => 'Title';

	/// en: 'Body'
	String get bodyLabel => 'Body';

	/// en: 'Online'
	String get onlineStatus => 'Online';

	/// en: 'Offline'
	String get offlineStatus => 'Offline';
}

// Path: settings
class TranslationsSettingsEn {
	TranslationsSettingsEn.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Settings'
	String get title => 'Settings';

	/// en: 'Notification settings'
	String get notifications => 'Notification settings';

	/// en: 'Notifications are enabled for this device.'
	String get notificationsEnabled => 'Notifications are enabled for this device.';

	/// en: 'Notifications are off. Enable them in system settings.'
	String get notificationsDenied => 'Notifications are off. Enable them in system settings.';

	/// en: 'Notifications have not been enabled yet.'
	String get notificationsNotDetermined => 'Notifications have not been enabled yet.';

	/// en: 'Enable notifications'
	String get enableNotifications => 'Enable notifications';
}

// Path: subscription
class TranslationsSubscriptionEn {
	TranslationsSubscriptionEn.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Paywall'
	String get title => 'Paywall';

	/// en: 'Choose a subscription plan to unlock premium features.'
	String get description => 'Choose a subscription plan to unlock premium features.';

	/// en: 'Pro is active'
	String get active => 'Pro is active';

	/// en: 'No active subscription'
	String get inactive => 'No active subscription';

	/// en: 'Renews on'
	String get expiresAtLabel => 'Renews on';

	/// en: 'No subscription packages are available right now.'
	String get noPackages => 'No subscription packages are available right now.';

	/// en: 'Subscribe'
	String get subscribe => 'Subscribe';

	/// en: 'Restore purchases'
	String get restorePurchases => 'Restore purchases';
}

// Path: common
class TranslationsCommonEn {
	TranslationsCommonEn.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Loading...'
	String get loading => 'Loading...';

	/// en: 'Retry'
	String get retry => 'Retry';
}

/// The flat map containing all translations for locale <en>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on Translations {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'app.title' => 'Flutter Supabase Starter',
			'auth.emailLabel' => 'Email',
			'auth.emailHint' => 'you@example.com',
			'auth.invalidEmailError' => 'Enter a valid email address.',
			'auth.sendOtpError' => 'We could not send a code right now.',
			'auth.sendOtp' => 'Send code',
			'auth.otpLabel' => 'Verification code',
			'auth.otpHint' => '123456',
			'auth.otpError' => 'That code is invalid or expired.',
			'auth.verifyOtp' => 'Verify code',
			'auth.resendOtp' => 'Resend code',
			'auth.resendCooldown' => 'Resend in 30s',
			'auth.signOut' => 'Sign out',
			'notes.title' => 'Notes',
			'notes.emptyState' => 'No notes yet.',
			'notes.newNoteTitle' => 'Untitled note',
			'notes.create' => 'New note',
			'notes.titleLabel' => 'Title',
			'notes.bodyLabel' => 'Body',
			'notes.onlineStatus' => 'Online',
			'notes.offlineStatus' => 'Offline',
			'settings.title' => 'Settings',
			'settings.notifications' => 'Notification settings',
			'settings.notificationsEnabled' => 'Notifications are enabled for this device.',
			'settings.notificationsDenied' => 'Notifications are off. Enable them in system settings.',
			'settings.notificationsNotDetermined' => 'Notifications have not been enabled yet.',
			'settings.enableNotifications' => 'Enable notifications',
			'subscription.title' => 'Paywall',
			'subscription.description' => 'Choose a subscription plan to unlock premium features.',
			'subscription.active' => 'Pro is active',
			'subscription.inactive' => 'No active subscription',
			'subscription.expiresAtLabel' => 'Renews on',
			'subscription.noPackages' => 'No subscription packages are available right now.',
			'subscription.subscribe' => 'Subscribe',
			'subscription.restorePurchases' => 'Restore purchases',
			'common.loading' => 'Loading...',
			'common.retry' => 'Retry',
			_ => null,
		};
	}
}

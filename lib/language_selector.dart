import 'package:flutter/material.dart';
import 'package:campus_gaurd_final/l10n/app_localizations.dart';
import 'package:campus_gaurd_final/language_provider.dart';

class LanguageSelector extends StatelessWidget {
  final LanguageProvider languageProvider;

  const LanguageSelector({super.key, required this.languageProvider});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return ListTile(
      leading: const Icon(Icons.language, color: Colors.blue),
      title: Text(l10n.language),
      trailing: DropdownButton<Locale>(
        value: languageProvider.locale,
        underline: const SizedBox(),
        items: LanguageProvider.supportedLocales.map((Locale locale) {
          String label;
          switch (locale.languageCode) {
            case 'en':
              label = l10n.english;
              break;
            case 'te':
              label = l10n.telugu;
              break;
            case 'hi':
              label = l10n.hindi;
              break;
            default:
              label = locale.languageCode;
          }
          return DropdownMenuItem<Locale>(
            value: locale,
            child: Text(label),
          );
        }).toList(),
        onChanged: (Locale? newLocale) {
          if (newLocale != null) {
            languageProvider.setLocale(newLocale);
          }
        },
      ),
    );
  }
}


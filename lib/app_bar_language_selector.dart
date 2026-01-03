import 'package:flutter/material.dart';
import 'package:campus_gaurd_final/l10n/app_localizations.dart';
import 'package:campus_gaurd_final/language_provider.dart';

class AppBarLanguageSelector extends StatelessWidget {
  final LanguageProvider languageProvider;

  const AppBarLanguageSelector({super.key, required this.languageProvider});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    // Get current language label
    String currentLabel;
    switch (languageProvider.locale.languageCode) {
      case 'en':
        currentLabel = l10n.english;
        break;
      case 'te':
        currentLabel = l10n.telugu;
        break;
      case 'hi':
        currentLabel = l10n.hindi;
        break;
      default:
        currentLabel = languageProvider.locale.languageCode;
    }

    return PopupMenuButton<Locale>(
      icon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.language, size: 20),
          const SizedBox(width: 4),
          Text(
            currentLabel,
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
      tooltip: l10n.language,
      onSelected: (Locale locale) {
        languageProvider.setLocale(locale);
      },
      itemBuilder: (BuildContext context) => LanguageProvider.supportedLocales.map((Locale locale) {
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
        return PopupMenuItem<Locale>(
          value: locale,
          child: Row(
            children: [
              if (languageProvider.locale == locale)
                const Icon(Icons.check, size: 18, color: Colors.purple)
              else
                const SizedBox(width: 18),
              const SizedBox(width: 8),
              Text(label),
            ],
          ),
        );
      }).toList(),
    );
  }
}


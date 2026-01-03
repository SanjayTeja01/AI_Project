import 'package:campus_gaurd_final/language_provider.dart';

class ChatbotTranslations {
  static final LanguageProvider _languageProvider = LanguageProvider();

  static String getLanguageCode() {
    return _languageProvider.locale.languageCode;
  }

  // Greetings
  static String getGreeting(String username) {
    final lang = getLanguageCode();
    if (lang == 'hi') {
      final greetings = [
        'नमस्ते $username! मैं आपकी कैसे मदद कर सकता हूं?',
        'हैलो! मैं आपकी क्या सहायता कर सकता हूं?',
        'नमस्कार $username! मैं आपकी सहायता के लिए तैयार हूं।',
      ];
      return greetings[DateTime.now().millisecond % greetings.length];
    } else if (lang == 'te') {
      final greetings = [
        'నమస్కారం $username! నేను మీకు ఎలా సహాయం చేయగలను?',
        'హలో! నేను మీకు ఏమి చేయగలను?',
        'హాయ్ $username! నేను మీకు సహాయం చేయడానికి సిద్ధంగా ఉన్నాను।',
      ];
      return greetings[DateTime.now().millisecond % greetings.length];
    } else {
      final greetings = [
        'Hello $username! How can I help you today?',
        'Hi there! What can I do for you?',
        'Hey $username! Ready to assist you.',
      ];
      return greetings[DateTime.now().millisecond % greetings.length];
    }
  }

  // SOS activation
  static String getSosActivating() {
    final lang = getLanguageCode();
    if (lang == 'hi') {
      return 'SOS तुरंत सक्रिय किया जा रहा है। संपर्क खोज रहा हूं।';
    } else if (lang == 'te') {
      return 'SOS వెంటనే సక్రియం చేయబడుతోంది. సంప్రదింపులను శోధిస్తున్నాను।';
    } else {
      return 'Activating SOS immediately. Searching for contacts.';
    }
  }

  // Profile opening
  static String getOpeningProfile() {
    final lang = getLanguageCode();
    if (lang == 'hi') {
      return 'आपकी प्रोफ़ाइल खोली जा रही है।';
    } else if (lang == 'te') {
      return 'మీ ప్రొఫైల్ తెరుస్తున్నాను।';
    } else {
      return 'Opening your profile.';
    }
  }

  // Contacts opening
  static String getOpeningContacts() {
    final lang = getLanguageCode();
    if (lang == 'hi') {
      return 'आपके आपातकालीन संपर्क दिखाए जा रहे हैं।';
    } else if (lang == 'te') {
      return 'మీ అత్యవసర సంప్రదింపులను చూపిస్తున్నాను।';
    } else {
      return 'Showing your emergency contacts.';
    }
  }

  // History opening
  static String getOpeningHistory() {
    final lang = getLanguageCode();
    if (lang == 'hi') {
      return 'आपका S.O.S. इतिहास खोला जा रहा है।';
    } else if (lang == 'te') {
      return 'మీ S.O.S. చరిత్రను తెరుస్తున్నాను।';
    } else {
      return 'Opening your S.O.S. history.';
    }
  }

  // Logout
  static String getLoggingOut() {
    final lang = getLanguageCode();
    if (lang == 'hi') {
      return 'आपको लॉग आउट किया जा रहा है। अलविदा!';
    } else if (lang == 'te') {
      return 'మిమ్మల్ని లాగ్ అవుట్ చేస్తున్నాను. వీడ్కోలు!';
    } else {
      return 'Logging you out. Goodbye!';
    }
  }

  // Stop SOS
  static String getStoppingSos() {
    final lang = getLanguageCode();
    if (lang == 'hi') {
      return 'SOS अलर्ट रोका जा रहा है...';
    } else if (lang == 'te') {
      return 'SOS హెచ్చరికను ఆపుతున్నాను...';
    } else {
      return 'Stopping SOS alert...';
    }
  }

  // Generic responses
  static String getWhatCanYouDo() {
    final lang = getLanguageCode();
    if (lang == 'hi') {
      return 'मैं आपकी कई चीजों में मदद कर सकता हूं! मैं SOS अलर्ट सक्रिय कर सकता हूं, आपके आपातकालीन संपर्क प्रबंधित कर सकता हूं, आपका SOS इतिहास दिखा सकता हूं, आपकी प्रोफ़ाइल खोल सकता हूं, और सुरक्षा प्रश्नों के उत्तर दे सकता हूं। बस मुझसे कुछ भी पूछें!';
    } else if (lang == 'te') {
      return 'నేను మీకు చాలా విషయాలలో సహాయం చేయగలను! నేను SOS హెచ్చరికలను సక్రియం చేయగలను, మీ అత్యవసర సంప్రదింపులను నిర్వహించగలను, మీ SOS చరిత్రను చూపించగలను, మీ ప్రొఫైల్ను తెరవగలను, మరియు భద్రత ప్రశ్నలకు సమాధానం ఇవ్వగలను। కేవలం నన్ను ఏదైనా అడగండి!';
    } else {
      return 'I can help you with many things! I can activate SOS alerts, manage your emergency contacts, show your SOS history, open your profile, and answer safety questions. Just ask me anything!';
    }
  }

  // Error messages
  static String getNoUserProfile() {
    final lang = getLanguageCode();
    if (lang == 'hi') {
      return 'मैं आपकी उपयोगकर्ता प्रोफ़ाइल नहीं ढूंढ सकता। कृपया फिर से लॉग इन करें।';
    } else if (lang == 'te') {
      return 'నేను మీ వినియోగదారు ప్రొఫైల్ను కనుగొనలేకపోయాను. దయచేసి మళ్లీ లాగిన్ చేయండి।';
    } else {
      return 'I cannot find your user profile. Please log in again.';
    }
  }

  // How are you responses
  static String getHowAreYou(String username) {
    final lang = getLanguageCode();
    if (lang == 'hi') {
      final responses = [
        'मैं बहुत अच्छा हूं! हमेशा आपकी सुरक्षा में मदद करने के लिए तैयार। मैं आपके लिए क्या कर सकता हूं?',
        'मैं ठीक हूं, धन्यवाद! मेरा मुख्य काम आपको सुरक्षित रखना है। क्या कोई मदद चाहिए?',
        'सब कुछ ठीक है! मैं हमेशा तैयार हूं जब आपको मेरी जरूरत हो। मैं कैसे सहायता कर सकता हूं?',
      ];
      return responses[DateTime.now().millisecond % responses.length];
    } else if (lang == 'te') {
      final responses = [
        'నేను చాలా బాగున్నాను! మిమ్మల్ని సురక్షితంగా ఉంచడంలో సహాయం చేయడానికి ఎల్లప్పుడూ సిద్ధంగా ఉన్నాను. నేను మీకు ఏమి చేయగలను?',
        'నేను బాగున్నాను, ధన్యవాదాలు! నా ప్రధాన పని మిమ్మల్ని సురక్షితంగా ఉంచడం. ఏదైనా సహాయం కావాలా?',
        'ఇక్కడ అన్నీ బాగున్నాయి! మీకు నాకు అవసరమైనప్పుడు నేను ఎల్లప్పుడూ సిద్ధంగా ఉన్నాను. నేను ఎలా సహాయం చేయగలను?',
      ];
      return responses[DateTime.now().millisecond % responses.length];
    } else {
      final responses = [
        'I\'m doing great! Always ready to help you stay safe. What can I do for you?',
        'I\'m fine, thank you! My main job is to keep you safe. Need any help?',
        'All good here! I\'m always ready when you need me. How can I assist?',
      ];
      return responses[DateTime.now().millisecond % responses.length];
    }
  }

  // Thank you responses
  static String getThankYou(String username) {
    final lang = getLanguageCode();
    if (lang == 'hi') {
      final responses = [
        'आपका स्वागत है! हमेशा मदद करने में खुशी होती है।',
        'मेरी खुशी है, $username! और कुछ चाहिए?',
        'मदद करके खुशी हुई! सुरक्षित रहें।',
      ];
      return responses[DateTime.now().millisecond % responses.length];
    } else if (lang == 'te') {
      final responses = [
        'మీకు స్వాగతం! సహాయం చేయడంలో ఎల్లప్పుడూ సంతోషం.',
        'నా ఆనందం, $username! మరేదైనా కావాలా?',
        'సహాయం చేయడంలో సంతోషం! సురక్షితంగా ఉండండి.',
      ];
      return responses[DateTime.now().millisecond % responses.length];
    } else {
      final responses = [
        'You\'re welcome! Always happy to help.',
        'My pleasure, $username! Anything else you need?',
        'Happy to help! Stay safe out there.',
      ];
      return responses[DateTime.now().millisecond % responses.length];
    }
  }

  // Goodbye responses
  static String getGoodbye(String username) {
    final lang = getLanguageCode();
    if (lang == 'hi') {
      final responses = [
        'अलविदा $username! सुरक्षित रहें!',
        'बाद में मिलते हैं! अपना ख्याल रखें।',
        'अलविदा! याद रखें, अगर आपको मेरी जरूरत हो तो मैं सिर्फ एक आवाज आदेश दूर हूं।',
      ];
      return responses[DateTime.now().millisecond % responses.length];
    } else if (lang == 'te') {
      final responses = [
        'వీడ్కోలు $username! సురక్షితంగా ఉండండి!',
        'తర్వాత కలుద్దాం! జాగ్రత్తగా ఉండండి.',
        'వీడ్కోలు! గుర్తుంచుకోండి, మీకు నాకు అవసరమైనప్పుడు నేను కేవలం ఒక వాయిస్ ఆదేశం దూరంలో ఉన్నాను.',
      ];
      return responses[DateTime.now().millisecond % responses.length];
    } else {
      final responses = [
        'Goodbye $username! Stay safe!',
        'See you later! Take care.',
        'Bye! Remember, I\'m just a voice command away if you need me.',
      ];
      return responses[DateTime.now().millisecond % responses.length];
    }
  }
}


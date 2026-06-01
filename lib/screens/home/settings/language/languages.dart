// ignore_for_file: deprecated_member_use

part of 'language_import.dart';

class Languages extends StatefulWidget {
  const Languages({super.key});

  @override
  State<Languages> createState() => _LanguagesState();
}

class _LanguagesState extends State<Languages> {
  late String currentLanguage;
  String? _selectedLanguage;

  final List<Map<String, String>> languageList = [
    {"code": "ar", "name": "Arabic (عربي)", "flag": "🇸🇦"},
    {"code": "en", "name": "English (UK)", "flag": "🇬🇧"},
    {"code": "de", "name": "German (Deutsch)", "flag": "🇩🇪"},
    {"code": "hi", "name": "Hindi (हिंदी)", "flag": "🇮🇳"},
    {"code": "id", "name": "Indonesian (Indonesia)", "flag": "🇮🇩"},
    {"code": "es", "name": "Spanish (Española)", "flag": "🇪🇸"},
    {"code": "vi", "name": "Vietnamese (Tiếng Việt)", "flag": "🇻🇳"},
  ];

  Future<void> _saveLanguage(String languageCode) async {
    await SharedPrefService.saveLanguage(languageCode);
    setState(() {
      currentLanguage = languageCode;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    currentLanguage = AppLocalizations.of(context)!.localeName;
  }

  void _changeLanguage(String code) {
    setState(() {
      _selectedLanguage = code;
    });
  }

  void _onContinue() {
    if (_selectedLanguage == null) return;
    MyApp.of(context)?.changeLanguage(Locale(_selectedLanguage!));
    _saveLanguage(_selectedLanguage!);
  }

  @override
  Widget build(BuildContext context) {
    final txt = AppTextColors.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: CommonAppBar(
        title: AppLocalizations.of(context)!.language,
        showBackButton: true,
      ),

      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: languageList.length,
                itemBuilder: (context, index) {
                  final lang = languageList[index];
                  bool isSelected =
                      (_selectedLanguage ?? currentLanguage) == lang["code"];

                  return GestureDetector(
                    onTap: () => _changeLanguage(lang["code"]!),
                    child: Container(
                      height: 45,
                      color: Colors.transparent,
                      child: Row(
                        children: [
                          Text(
                            lang["flag"]!,
                            style: TextStyle(fontSize: 15.5.spMax),
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: Text(
                              lang["name"]!,
                              style: AppTextStyles.bodyText.copyWith(
                                fontSize: 13.5,
                                color: txt.title,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.onPrimary
                                    : txt.muted,
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              isSelected ? Icons.circle : Icons.circle_outlined,
                              size: 16.spMax,
                              color: isSelected
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : Colors.transparent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 5, 16, 35),
        child: _buildContinueButton(),
      ),
    );
  }

  Widget _buildContinueButton() {
    final bool isEnabled =
        _selectedLanguage != null && _selectedLanguage != currentLanguage;
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: isEnabled ? _onContinue : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          disabledBackgroundColor: const Color(0x269B3046),
          disabledForegroundColor: const Color(0xFF898989),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          'Continue',
          style: AppTextStyles.bodyText.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: isEnabled
                ? Colors.white
                : const Color(0xFF898989).withOpacity(0.6),
          ),
        ),
      ),
    );
  }
}

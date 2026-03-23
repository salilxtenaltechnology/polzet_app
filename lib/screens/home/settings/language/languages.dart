// ignore_for_file: deprecated_member_use

part of 'language_import.dart';

class Languages extends StatefulWidget {
  const Languages({super.key});

  @override
  State<Languages> createState() => _LanguagesState();
}

class _LanguagesState extends State<Languages> {
  late String currentLanguage;

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
    MyApp.of(context)?.changeLanguage(Locale(code));
    _saveLanguage(code);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 25.h,
        leading: const PrimaryBackButton(),
        title: Text(
          AppLocalizations.of(context)!.language,
          style: CustomTextStyles.appBarTitleText(context),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.background,
        surfaceTintColor: Theme.of(context).colorScheme.background,
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
                  bool isSelected = currentLanguage == lang["code"];

                  return GestureDetector(
                    onTap: () => _changeLanguage(lang["code"]!),
                    child: Container(
                      height: 35.h,
                      margin: EdgeInsets.symmetric(vertical: 5.h),
                      padding: EdgeInsets.symmetric(horizontal: 10.w),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(
                                context,
                              ).colorScheme.primary.withOpacity(0.13)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(
                                  context,
                                ).colorScheme.onBackground.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
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
                              style: CustomTextStyles.lblPrimaryText(context),
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.circle,
                              size: 16.spMax,
                              color: Theme.of(context).colorScheme.primary,
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
    );
  }
}

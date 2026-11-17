import '../../core/i18n/i18n.dart';

/// "1 pista" / "3 pistas": número + palabra en singular o plural. Las palabras
/// llegan ya traducidas por quien llama.
String plural(int n, String singular, String pluralForm) =>
    '$n ${n == 1 ? singular : pluralForm}';

String nPistas(int n) => plural(n, tr('pista'), tr('pistas'));

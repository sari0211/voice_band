import 'constants.dart';

class IeltsBandMapper {
  static double mapScoreToBand(double overallScore) {
    for (final entry in AppConstants.bandThresholds.entries) {
      if (overallScore >= entry.key) {
        return entry.value;
      }
    }
    return 1.0;
  }

  static double calculateOverallScore({
    required double pronunciation,
    required double fluency,
    required double completeness,
    required double prosody,
  }) {
    return pronunciation * AppConstants.pronunciationWeight +
        fluency * AppConstants.fluencyWeight +
        prosody * AppConstants.prosodyWeight +
        completeness * AppConstants.completenessWeight;
  }

  static String bandLabel(double band) {
    if (band >= 8.5) return 'Expert';
    if (band >= 7.5) return 'Very Good';
    if (band >= 6.5) return 'Competent';
    if (band >= 5.5) return 'Modest';
    if (band >= 4.5) return 'Limited';
    if (band >= 3.5) return 'Extremely Limited';
    return 'Non User';
  }
}

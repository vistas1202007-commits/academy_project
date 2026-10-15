const List<Map<String, String>> kCourseOptions = [
  {'value': 'Electrical', 'label': 'Electrical - Assistant Electrician (4 months)'},
  {'value': 'BPO', 'label': 'BPO - Business Process Outsourcing (4 months)'},
  {'value': 'Retail', 'label': 'Retail - Retail Sales Associate (3 months)'},
  {'value': 'Beauty', 'label': 'Beauty - Beauty & Wellness Assistant (4 months)'},
  {'value': 'CAD', 'label': 'CAD - Computer-Aided Drafting (4 months)'},
  {'value': 'Hospitality', 'label': 'Hospitality - Hospitality Assistant (3 months)'},
];

/// For getting the course value from a batch label prefix (ELC-01 -> ELC)
const Map<String, String> kBatchPrefixToCourse = {
  'ELC': 'Electrical',
  'BPO': 'BPO',
  'RTL': 'Retail',
  'BTY': 'Beauty',
  'CAD': 'CAD',
  'HSP': 'Hospitality',
};

import sys
errors = []

def patch(fpath, old, new, label):
    with open(fpath, "r", encoding="utf-8") as f:
        src = f.read()
    n = src.count(old)
    if n == 0:
        errors.append(f"[{label}] anchor not found in {fpath}")
        return
    if n > 1:
        errors.append(f"[{label}] anchor not unique ({n}x) in {fpath}")
        return
    with open(fpath, "w", encoding="utf-8") as f:
        f.write(src.replace(old, new, 1))
    print(f"  [+] {label}")

NS  = "lib/features/nutrition/nutrition_screen.dart"
PRV = "lib/core/providers.dart"

print("\n── Fix 1: intl TextDirection conflict ─────────────")

# The intl package defines its own TextDirection with RTL/LTR (uppercase),
# which shadows Flutter's TextDirection.rtl / .ltr (lowercase).
# Fix: hide intl's TextDirection so Flutter's is used.
with open(NS, "r", encoding="utf-8") as f:
    ns = f.read()
if "hide TextDirection" in ns:
    print("  [=] intl import already has hide TextDirection (skip)")
elif "import 'package:intl/intl.dart';" in ns:
    ns = ns.replace(
        "import 'package:intl/intl.dart';",
        "import 'package:intl/intl.dart' hide TextDirection;")
    with open(NS, "w", encoding="utf-8") as f:
        f.write(ns)
    print("  [+] nutrition: intl hide TextDirection")
else:
    errors.append("[nutrition: intl import] import not found — check file manually")

print("\n── Fix 2: caloriesBurnedTodayProvider missing ─────")

with open(PRV, "r", encoding="utf-8") as f:
    prv = f.read()

if "caloriesBurnedTodayProvider" in prv:
    print("  [=] caloriesBurnedTodayProvider already in providers.dart (skip)")
else:
    patch(PRV,
        "final scanProvider = StateNotifierProvider<ScanNotifier, ScanState>((ref) => ScanNotifier());",
        "final caloriesBurnedTodayProvider =\n"
        "    StateNotifierProvider<BurnedCaloriesNotifier, double>(\n"
        "        (ref) => BurnedCaloriesNotifier());\n"
        "class BurnedCaloriesNotifier extends StateNotifier<double> {\n"
        "  BurnedCaloriesNotifier() : super(0.0) { _init(); }\n"
        "  Future<void> _init() async { state = await AppDatabase.getTodayBurnedKcal(); }\n"
        "  void addBurned(double kcal) => state = state + kcal;\n"
        "}\n\n"
        "final workoutWeekProvider = FutureProvider<Set<String>>((ref) async {\n"
        "  ref.watch(caloriesBurnedTodayProvider);\n"
        "  return AppDatabase.getWeeklyWorkoutDays();\n"
        "});\n\n"
        "final scanProvider = StateNotifierProvider<ScanNotifier, ScanState>((ref) => ScanNotifier());",
        "providers: caloriesBurnedTodayProvider + workoutWeekProvider")

print("")
if errors:
    print("ERRORS:")
    for e in errors:
        print(f"  !! {e}")
    sys.exit(1)
else:
    print("All patches applied OK")

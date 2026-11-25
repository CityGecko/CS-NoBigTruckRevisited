// MIT License, see LICENSE.

using AlgernonCommons;
using AlgernonCommons.Notifications;
using AlgernonCommons.Patching;
using AlgernonCommons.Translation;
using ICities;

namespace NoBigTruck
{
    /// <summary>
    /// Loading extension: Harmony check (AlgernonCommons) and a hint when Advanced Vehicle Options is missing.
    /// </summary>
    public sealed class Loading : PatcherLoadingBase<OptionsPanel, Patcher>
    {
        protected override void LoadedActions(LoadMode mode)
        {
            base.LoadedActions(mode);

            // Without AVO nobody can mark vehicles as "Large Vehicle", so No Big Truck has nothing to filter.
            if (!Plugins.IsAvoEnabled)
            {
                Logging.KeyMessage("Advanced Vehicle Options is not enabled - no vehicle is marked as large vehicle");
                ListNotification notification = NotificationBase.ShowNotification<ListNotification>();
                notification?.AddParas(Translations.Translate("AVO_MISSING"));
            }

            LogSharedPatches();
        }

        // Support aid: which mods patch the methods No Big Truck transpiles, in which order (e.g. Vehicle Selector).
        private static void LogSharedPatches()
        {
            try
            {
                var methods = new System.Reflection.MethodBase[]
                {
                    HarmonyLib.AccessTools.Method(typeof(IndustrialBuildingAI), nameof(IndustrialBuildingAI.StartTransfer)),
                    HarmonyLib.AccessTools.Method(typeof(IndustrialExtractorAI), nameof(IndustrialExtractorAI.StartTransfer)),
                    HarmonyLib.AccessTools.Method(typeof(WarehouseAI), nameof(WarehouseAI.StartTransfer)),
                    HarmonyLib.AccessTools.Method(typeof(OutsideConnectionAI), "StartConnectionTransferImpl"),
                    HarmonyLib.AccessTools.Method(typeof(CargoTruckAI), nameof(CargoTruckAI.ChangeVehicleType), new[] { typeof(VehicleInfo), typeof(ushort), typeof(Vehicle).MakeByRefType(), typeof(PathUnit.Position), typeof(uint) }),
                };
                var sb = new System.Text.StringBuilder("Harmony patches on shared methods (transpilers in execution order):");
                foreach (var method in methods)
                {
                    if (method == null)
                        continue;
                    var info = HarmonyLib.Harmony.GetPatchInfo(method);
                    sb.Append("\n  ").Append(method.DeclaringType.Name).Append('.').Append(method.Name).Append(": ");
                    if (info == null)
                    {
                        sb.Append("not patched");
                        continue;
                    }

                    var transpilers = new System.Collections.Generic.List<HarmonyLib.Patch>(info.Transpilers);
                    transpilers.Sort((a, b) => a.CompareTo(b));
                    foreach (var patch in transpilers)
                        sb.Append(patch.owner).Append(" (priority ").Append(patch.priority).Append(", index ").Append(patch.index).Append(") ");
                }

                sb.Append("\n  Vehicle Selector enabled: ").Append(Plugins.IsVehicleSelectorEnabled);
                Logging.KeyMessage(sb.ToString());
            }
            catch (System.Exception e)
            {
                Logging.LogException(e, "exception listing shared patches");
            }
        }
    }
}

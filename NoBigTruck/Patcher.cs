// MIT License, see LICENSE.

using System;
using System.Reflection;
using AlgernonCommons;
using AlgernonCommons.Patching;
using HarmonyLib;

namespace NoBigTruck
{
    /// <summary>
    /// Applies all Harmony patches explicitly, one log line per patch ("patched ..." or "ERROR: patch failed ...").
    /// The game members checked here are also covered by GameScan\Scan-Game.ps1.
    /// </summary>
    public sealed class Patcher : PatcherBase
    {
        private int applied;
        private int failed;

        protected override void OnPatchAll(Harmony harmony)
        {
            applied = 0;
            failed = 0;

            var transfer = Method(typeof(Patches), nameof(Patches.StartTransfer_Transpiler));
            Transpile(harmony, typeof(IndustrialBuildingAI), nameof(IndustrialBuildingAI.StartTransfer), null, transfer);
            Transpile(harmony, typeof(IndustrialExtractorAI), nameof(IndustrialExtractorAI.StartTransfer), null, transfer);
            Transpile(harmony, typeof(OutsideConnectionAI), "StartConnectionTransferImpl", null, transfer);
            Transpile(harmony, typeof(WarehouseAI), nameof(WarehouseAI.StartTransfer), null, Method(typeof(Patches), nameof(Patches.WarehouseAI_StartTransfer_Transpiler)));
            Transpile(harmony, typeof(CargoTruckAI), nameof(CargoTruckAI.ChangeVehicleType),
                new[] { typeof(VehicleInfo), typeof(ushort), typeof(Vehicle).MakeByRefType(), typeof(PathUnit.Position), typeof(uint) },
                Method(typeof(Patches), nameof(Patches.CargoTruckAI_ChangeVehicleType_Transpiler)));
            Prefix(harmony, typeof(CargoTruckAI), nameof(CargoTruckAI.StartTransfer),
                new[] { typeof(ushort), typeof(Vehicle).MakeByRefType(), typeof(TransferManager.TransferReason), typeof(TransferManager.TransferOffer) },
                Method(typeof(Patches), nameof(Patches.CargoTruckAI_StartTransfer_Prefix)));
            Postfix(harmony, typeof(VehicleManager), nameof(VehicleManager.RefreshTransferVehicles), null, Method(typeof(Manager), nameof(Manager.RefreshTransferVehicles)));

            // Mark "a building is dispatching a new truck", so the rerouting prefix above leaves those trucks alone.
            Dispatch(harmony, typeof(IndustrialBuildingAI), nameof(IndustrialBuildingAI.StartTransfer));
            Dispatch(harmony, typeof(IndustrialExtractorAI), nameof(IndustrialExtractorAI.StartTransfer));
            Dispatch(harmony, typeof(WarehouseAI), nameof(WarehouseAI.StartTransfer));
            Dispatch(harmony, typeof(OutsideConnectionAI), "StartConnectionTransferImpl");

            // Advanced Vehicle Options: refresh the cache when "Large Vehicle" is ticked, and let AVO show that checkbox.
            Type avoPanel = AccessTools.TypeByName("AdvancedVehicleOptionsUID.GUI.UIOptionPanel");
            Type avoCompat = AccessTools.TypeByName("AdvancedVehicleOptionsUID.Compatibility.NoBigTruckCompatibilityPatch");
            if (avoPanel == null || avoCompat == null)
            {
                Logging.KeyMessage("Advanced Vehicle Options not found - AVO patches skipped");
            }
            else
            {
                Postfix(harmony, avoPanel, "OnCheckChanged", null, Method(typeof(Manager), nameof(Manager.AVOCheckChanged)));
                Prefix(harmony, avoCompat, "IsNBTActive", null, Method(typeof(Patches), nameof(Patches.NBTCheckPrefix)));
            }

            if (Plugins.IsVehicleSelectorEnabled)
                Logging.KeyMessage("Vehicle Selector is enabled - vehicle selection is left to Vehicle Selector except for outside connections");

            Logging.KeyMessage("Harmony patches: ", applied, " applied, ", failed, " failed");
        }

        private static MethodInfo Method(Type type, string name) => AccessTools.Method(type, name);

        private void Transpile(Harmony harmony, Type type, string name, Type[] args, MethodInfo patch) =>
            Apply(harmony, type, name, args, patch, "TRANSPILER", target => harmony.Patch(target, transpiler: new HarmonyMethod(patch)));

        private void Prefix(Harmony harmony, Type type, string name, Type[] args, MethodInfo patch) =>
            Apply(harmony, type, name, args, patch, "PREFIX", target => harmony.Patch(target, prefix: new HarmonyMethod(patch)));

        private void Postfix(Harmony harmony, Type type, string name, Type[] args, MethodInfo patch) =>
            Apply(harmony, type, name, args, patch, "POSTFIX", target => harmony.Patch(target, postfix: new HarmonyMethod(patch)));

        private void Dispatch(Harmony harmony, Type type, string name) =>
            Apply(harmony, type, name, null, Method(typeof(Patches), nameof(Patches.DispatchPrefix)), "PREFIX+FINALIZER",
                target => harmony.Patch(target, prefix: new HarmonyMethod(Method(typeof(Patches), nameof(Patches.DispatchPrefix))), finalizer: new HarmonyMethod(Method(typeof(Patches), nameof(Patches.DispatchFinalizer)))));

        private void Apply(Harmony harmony, Type type, string name, Type[] args, MethodInfo patch, string kind, Action<MethodInfo> patchAction)
        {
            string label = kind + " " + type?.FullName + "." + name + " <- " + patch?.DeclaringType?.Name + "." + patch?.Name;
            try
            {
                MethodInfo target = args == null ? AccessTools.Method(type, name) : AccessTools.Method(type, name, args);
                if (target == null || patch == null)
                {
                    failed++;
                    Logging.Error("patch failed (method not found): ", label);
                    return;
                }

                patchAction(target);
                applied++;
                Logging.KeyMessage("patched: ", label);
            }
            catch (Exception e)
            {
                failed++;
                Logging.LogException(e, "patch failed: ", label);
            }
        }
    }
}

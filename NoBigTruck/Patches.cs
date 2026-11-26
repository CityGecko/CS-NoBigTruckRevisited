// MIT License, see LICENSE. Original code by MacSergey (No Big Truck), Vehicle Selector support by Will,
// game 1.21 updates and the rerouting prefix by CityGecko (Tim).

using System;
using System.Collections.Generic;
using System.Reflection;
using System.Reflection.Emit;
using ColossalFramework.Math;
using HarmonyLib;

namespace NoBigTruck
{
    /// <summary>
    /// Harmony patch methods. Applied by <see cref="Patcher"/>.
    /// </summary>
    public static class Patches
    {
        private static MethodInfo ReplaceMethod { get; }
        static Patches()
        {
            ReplaceMethod = AccessTools.Method(typeof(VehicleManager), nameof(VehicleManager.GetRandomVehicleInfo), new Type[] { typeof(Randomizer).MakeByRefType(), typeof(ItemClass.Service), typeof(ItemClass.SubService), typeof(ItemClass.Level) });
        }

        public static IEnumerable<CodeInstruction> StartTransfer_Transpiler(MethodBase original, ILGenerator generator, IEnumerable<CodeInstruction> instructions)
        {
            if (Plugins.IsVehicleSelectorEnabled && original.DeclaringType != typeof(OutsideConnectionAI))
            {
                foreach (var instruction in instructions)
                    yield return instruction;
                yield break;
            }

            foreach (var instruction in instructions)
            {
                if (instruction.opcode == OpCodes.Callvirt && instruction.operand == ReplaceMethod)
                {
                    yield return new CodeInstruction(OpCodes.Ldarg_S, original.IsStatic ? 0 : 1);
                    yield return new CodeInstruction(OpCodes.Ldarga_S, original.IsStatic ? 3 : 4);
                    yield return new CodeInstruction(OpCodes.Call, AccessTools.PropertyGetter(typeof(TransferManager.TransferOffer), nameof(TransferManager.TransferOffer.Building)));
                    yield return new CodeInstruction(OpCodes.Ldarg_S, original.IsStatic ? 2 : 3);
                    yield return new CodeInstruction(OpCodes.Call, AccessTools.Method(typeof(Manager), nameof(Manager.GetRandomVehicleInfo)));
                }
                else
                    yield return instruction;
            }
        }
        public static IEnumerable<CodeInstruction> WarehouseAI_StartTransfer_Transpiler(MethodBase original, ILGenerator generator, IEnumerable<CodeInstruction> instructions)
        {
            if (Plugins.IsVehicleSelectorEnabled)
            {
                foreach (var instruction in instructions)
                    yield return instruction;
                yield break;
            }

            var method = AccessTools.Method(typeof(WarehouseAI), nameof(WarehouseAI.GetTransferVehicleService));
            foreach (var instruction in instructions)
            {
                if (instruction.opcode == OpCodes.Call && instruction.operand == method)
                {
                    yield return new CodeInstruction(OpCodes.Ldarg_S, 1);
                    yield return new CodeInstruction(OpCodes.Ldarga_S, 4);
                    yield return new CodeInstruction(OpCodes.Call, AccessTools.PropertyGetter(typeof(TransferManager.TransferOffer), nameof(TransferManager.TransferOffer.Building)));
                    yield return new CodeInstruction(OpCodes.Call, AccessTools.Method(typeof(Manager), nameof(Manager.GetTransferVehicleService)));
                }
                else
                    yield return instruction;
            }
        }
        public static IEnumerable<CodeInstruction> CargoTruckAI_ChangeVehicleType_Transpiler(MethodBase original, ILGenerator generator, IEnumerable<CodeInstruction> instructions)
        {
            if (Plugins.IsVehicleSelectorEnabled)
            {
                foreach (var instruction in instructions)
                    yield return instruction;
                yield break;
            }

            foreach (var instruction in instructions)
            {
                if (instruction.opcode == OpCodes.Callvirt && instruction.operand == ReplaceMethod)
                {
                    yield return new CodeInstruction(OpCodes.Ldloc_S, 6);
                    yield return new CodeInstruction(OpCodes.Ldloc_S, 7);
                    yield return new CodeInstruction(OpCodes.Ldarg_2);
                    yield return new CodeInstruction(OpCodes.Ldfld, AccessTools.Field(typeof(Vehicle), nameof(Vehicle.m_transferType)));
                    yield return new CodeInstruction(OpCodes.Call, AccessTools.Method(typeof(Manager), nameof(Manager.GetRandomVehicleInfo)));
                }
                else
                    yield return instruction;
            }
        }

        // A loaded cargo truck that lost its target (rest of the load after a partial delivery, arrival from a
        // cargo train/ship at the destination station, target gone) offers itself to the TransferManager and
        // gets a new target here - no vehicle is selected, so the GetRandomVehicleInfo patches never see it.
        // Large vehicles must not be sent to buildings covered by a rule: the target is refused, the truck keeps
        // waiting and, as in vanilla when no target is found, returns with its load after a short time.
        // No new offer is added here on purpose: this runs inside TransferManager's matching loop.
        // Not applied while a building dispatches a NEW truck (see DispatchPrefix): there the vehicle selection
        // (No Big Truck, or Vehicle Selector which takes precedence) has already decided.
        public static bool CargoTruckAI_StartTransfer_Prefix(ushort vehicleID, ref Vehicle data, TransferManager.TransferReason material, TransferManager.TransferOffer offer)
        {
            if (dispatchDepth > 0)
                return true;

            if (material != TransferManager.TransferReason.Goods || material != (TransferManager.TransferReason)data.m_transferType || (data.m_flags & Vehicle.Flags.WaitingTarget) == 0)
                return true;

            var info = data.Info;
            if (info == null || !info.m_isLargeVehicle)
                return true;

            return !Manager.IsRestrictedTarget(data.m_sourceBuilding, offer.Building);
        }

        // > 0 while IndustrialBuildingAI/IndustrialExtractorAI/WarehouseAI.StartTransfer or
        // OutsideConnectionAI.StartConnectionTransferImpl runs, i.e. while a building creates and sends a new truck.
        [ThreadStatic]
        private static int dispatchDepth;

        public static void DispatchPrefix() => dispatchDepth++;

        // Finalizer: runs also if the original method throws, so the counter cannot get stuck.
        public static Exception DispatchFinalizer(Exception __exception)
        {
            if (dispatchDepth > 0)
                dispatchDepth--;
            return __exception;
        }

        public static bool NBTCheckPrefix(ref bool __result)
        {
            __result = true;
            return false;
        }
    }
}

// MIT License, see LICENSE.

using System;
using ColossalFramework.Plugins;
using HarmonyLib;

namespace NoBigTruck
{
    /// <summary>
    /// Finds other mods: Advanced Vehicle Options (marks large vehicles) and Vehicle Selector (selects vehicles itself).
    /// </summary>
    internal static class Plugins
    {
        private const ulong AvoWorkshopId = 1548831935ul;
        private const ulong VehicleSelectorWorkshopId = 2882769913ul;

        /// <summary>Gets a value indicating whether Advanced Vehicle Options is enabled (any build, also local ones).</summary>
        internal static bool IsAvoEnabled => IsEnabled(AvoWorkshopId, "AdvancedVehicleOptions", "Advanced Vehicle Options", AccessTools.TypeByName("AdvancedVehicleOptionsUID.GUI.UIOptionPanel"));

        /// <summary>Gets a value indicating whether Vehicle Selector is enabled.</summary>
        internal static bool IsVehicleSelectorEnabled => IsEnabled(VehicleSelectorWorkshopId, "VehicleSelector", "Vehicle Selector", null);

        // Checks, in this order: workshop ID, assembly (DLL) name, mod name. The DLL name also works for local copies
        // without workshop ID and before the game has created the mod instance (e.g. while No Big Truck is patching).
        private static bool IsEnabled(ulong workshopId, string assemblyName, string namePrefix, Type typeInAssembly)
        {
            try
            {
                foreach (PluginManager.PluginInfo plugin in PluginManager.instance.GetPluginsInfo())
                {
                    if (!plugin.isEnabled)
                        continue;

                    if (plugin.publishedFileID.AsUInt64 == workshopId)
                        return true;

                    foreach (System.Reflection.Assembly assembly in plugin.GetAssemblies())
                    {
                        if (string.Equals(assembly.GetName().Name, assemblyName, StringComparison.OrdinalIgnoreCase))
                            return true;
                    }

                    object instance = plugin.userModInstance;
                    if (instance == null)
                        continue;

                    if (typeInAssembly != null && instance.GetType().Assembly == typeInAssembly.Assembly)
                        return true;

                    if (instance is ICities.IUserMod mod && mod.Name != null && mod.Name.StartsWith(namePrefix, StringComparison.OrdinalIgnoreCase))
                        return true;
                }
            }
            catch (Exception e)
            {
                AlgernonCommons.Logging.LogException(e, "exception checking for ", namePrefix);
            }

            return false;
        }
    }
}

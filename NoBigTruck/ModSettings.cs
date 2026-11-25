// MIT License, see LICENSE.

using System.IO;
using System.Xml.Serialization;
using AlgernonCommons.XML;
using ColossalFramework.IO;

namespace NoBigTruck
{
    /// <summary>
    /// Mod settings (language, last "what's new" version, detailed logging) via AlgernonCommons.
    /// The rules are stored separately in NoBigTruck.xml (see <see cref="RuleSettings"/>).
    /// </summary>
    [XmlRoot("NoBigTruckRevisited")]
    public sealed class ModSettings : SettingsXMLBase
    {
        private static string SettingsFile => Path.Combine(DataLocation.localApplicationData, "NoBigTruckRevisited-Settings.xml");

        internal static void Load() => XMLFileUtils.Load<ModSettings>(SettingsFile);

        internal static void Save() => XMLFileUtils.Save<ModSettings>(SettingsFile);
    }
}

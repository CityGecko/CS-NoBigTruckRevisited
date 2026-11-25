// MIT License, see LICENSE. Rule model and file format from MacSergey's No Big Truck.

using System;
using System.Collections.Generic;
using System.IO;
using System.Xml;
using AlgernonCommons;
using ColossalFramework.IO;

namespace NoBigTruck
{
    [Flags]
    public enum SourceBuildingTypes
    {
        None = 0,
        Industry = 1,
        Outside = 2,
        Warehouse = 4,
        All = Industry | Outside | Warehouse,
    }

    [Flags]
    public enum TargetBuildingTypes
    {
        None = 0,
        Low = 1,
        High = 2,
        Eco = 4,
        Leisure = 8,
        Tourist = 16,
        Industry = 32,
        Outside = 64,
        Warehouse = 128,
        Disaster = 256,
        WallToWall = 512,
        All = Low | High | Eco | Leisure | Tourist | WallToWall,
    }

    /// <summary>
    /// One delivery rule: goods from the source types to the target types are delivered by small vehicles only
    /// (optionally only for targets up to MaxLength x MaxWidth cells).
    /// </summary>
    public sealed class Rule
    {
        public SourceBuildingTypes SourceBuildings = SourceBuildingTypes.All;
        public TargetBuildingTypes TargetBuildings = TargetBuildingTypes.All;
        public bool UseSize = false;
        public int MaxLength = 4;
        public int MaxWidth = 4;
    }

    /// <summary>
    /// Rules of all players, stored in %LOCALAPPDATA%\Colossal Order\Cities_Skylines\NoBigTruck.xml.
    /// Same format as No Big Truck 1.x, so existing rules are kept:
    /// &lt;Config&gt;&lt;Rule Source="7" Target="31" UseSize="1" MaxLength="4" MaxWidth="4" /&gt;&lt;/Config&gt;
    /// </summary>
    public static class RuleSettings
    {
        // Read by the simulation thread, changed by the options panel: always replace the whole list.
        private static volatile Rule[] rules = new Rule[0];

        public static string ConfigFile => Path.Combine(DataLocation.localApplicationData, "NoBigTruck.xml");

        public static Rule[] Rules => rules;

        public static void Load()
        {
            var list = new List<Rule>();
            try
            {
                if (!File.Exists(ConfigFile))
                {
                    Logging.KeyMessage("rule file not found, creating default rule: ", ConfigFile);
                    list.Add(new Rule());
                    rules = list.ToArray();
                    Save();
                    return;
                }

                var doc = new XmlDocument();
                doc.Load(ConfigFile);
                foreach (XmlElement element in doc.GetElementsByTagName("Rule"))
                {
                    var rule = new Rule
                    {
                        SourceBuildings = (SourceBuildingTypes)ReadInt(element, "Source", (int)SourceBuildingTypes.All),
                        TargetBuildings = (TargetBuildingTypes)ReadInt(element, "Target", (int)TargetBuildingTypes.All),
                        UseSize = ReadBool(element, "UseSize", false),
                        MaxLength = ReadInt(element, "MaxLength", 4),
                        MaxWidth = ReadInt(element, "MaxWidth", 4),
                    };
                    list.Add(rule);
                }
            }
            catch (Exception e)
            {
                Logging.LogException(e, "exception reading rule file ", ConfigFile);
            }

            rules = list.ToArray();
            Logging.KeyMessage("rules loaded: ", rules.Length);
        }

        /// <summary>Saves the rules; returns false if the file could not be written.</summary>
        public static bool Save()
        {
            try
            {
                var doc = new XmlDocument();
                doc.AppendChild(doc.CreateXmlDeclaration("1.0", "utf-8", null));
                XmlElement root = doc.CreateElement("Config");
                doc.AppendChild(root);
                foreach (Rule rule in rules)
                {
                    XmlElement element = doc.CreateElement("Rule");
                    element.SetAttribute("Source", ((int)rule.SourceBuildings).ToString());
                    element.SetAttribute("Target", ((int)rule.TargetBuildings).ToString());
                    element.SetAttribute("UseSize", rule.UseSize ? "1" : "0");
                    element.SetAttribute("MaxLength", rule.MaxLength.ToString());
                    element.SetAttribute("MaxWidth", rule.MaxWidth.ToString());
                    root.AppendChild(element);
                }

                doc.Save(ConfigFile);
                return true;
            }
            catch (Exception e)
            {
                Logging.LogException(e, "exception saving rule file ", ConfigFile);
                return false;
            }
        }

        /// <summary>Replaces the rule list (copy-on-write for the simulation thread) and saves it.</summary>
        public static bool Set(IEnumerable<Rule> newRules)
        {
            rules = new List<Rule>(newRules).ToArray();
            return Save();
        }

        private static int ReadInt(XmlElement element, string name, int defaultValue) =>
            int.TryParse(element.GetAttribute(name), out int value) ? value : defaultValue;

        private static bool ReadBool(XmlElement element, string name, bool defaultValue)
        {
            string value = element.GetAttribute(name);
            if (string.IsNullOrEmpty(value))
                return defaultValue;
            return value == "1" || value.Equals("true", StringComparison.OrdinalIgnoreCase);
        }
    }
}

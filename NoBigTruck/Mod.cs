// MIT License, see LICENSE. Original mod by MacSergey (No Big Truck), continued as No Big Truck Revisited.

using System;
using AlgernonCommons;
using AlgernonCommons.Notifications;
using AlgernonCommons.Patching;
using AlgernonCommons.Translation;
using ICities;

namespace NoBigTruck
{
    /// <summary>
    /// Mod entry point. Base classes from AlgernonCommons (MIT, algernon).
    /// </summary>
    public sealed class Mod : PatcherMod<OptionsPanel, Patcher>, IUserMod
    {
        public override string BaseName => "No Big Truck Revisited";

        public override string HarmonyID => "citygecko.nobigtruck.revisited";

        public string Description => Translations.Translate("MOD_DESCRIPTION");

        public override WhatsNewMessage[] WhatsNewMessages => new WhatsNewMessage[]
        {
            new WhatsNewMessage
            {
                Version = new Version("2.0.0.0"),
                MessagesAreKeys = true,
                Messages = new string[]
                {
                    "WHATSNEW_2_0_0_1",
                    "WHATSNEW_2_0_0_2",
                    "WHATSNEW_2_0_0_3",
                    "WHATSNEW_2_0_0_4",
                    "WHATSNEW_2_0_0_5",
                    "WHATSNEW_2_0_0_6",
                },
            },
        };

        public override void LoadSettings()
        {
            ModSettings.Load();
            RuleSettings.Load();
        }

        public override void SaveSettings()
        {
            ModSettings.Save();
            RuleSettings.Save();
        }
    }
}

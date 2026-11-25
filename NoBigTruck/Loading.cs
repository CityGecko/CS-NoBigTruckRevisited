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
        }
    }
}

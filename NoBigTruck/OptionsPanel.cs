// MIT License, see LICENSE.

using System.Collections.Generic;
using AlgernonCommons.Translation;
using AlgernonCommons.UI;
using ColossalFramework.UI;
using UnityEngine;

namespace NoBigTruck
{
    /// <summary>
    /// Options page: language selection and the rule list. Each rule is a group with checkboxes for the source and
    /// target building types, "check target size" and the maximum lot size. Every change is saved immediately.
    /// </summary>
    public sealed class OptionsPanel : OptionsPanelBase
    {
        private const float Margin = 5f;
        private const float RuleHeight = 236f;
        private const float RuleGap = 10f;
        private const float Column = 200f;

        private UIScrollablePanel rulesPanel;

        protected override void Setup()
        {
            float y = Margin;

            UIDropDown language = UIDropDowns.AddPlainDropDown(this, Margin, y, Translations.Translate("LANGUAGE_CHOICE"), Translations.LanguageList, Translations.Index);
            language.eventSelectedIndexChanged += (c, index) =>
            {
                Translations.Index = index;
                ModSettings.Save();
                OptionsPanelManager<OptionsPanel>.LocaleChanged();
            };
            y += 70f;

            UILabel title = UILabels.AddLabel(this, Margin, y, Translations.Translate("RULES_TITLE"), width - (Margin * 2f), 1.2f);
            y += title.height + 4f;
            UILabel hint = UILabels.AddLabel(this, Margin, y, Translations.Translate("RULES_HINT"), width - (Margin * 2f) - 20f, 0.8f);
            hint.wordWrap = true;
            hint.autoHeight = true;
            y += hint.height + 10f;

            rulesPanel = AddUIComponent<UIScrollablePanel>();
            rulesPanel.relativePosition = new Vector2(Margin, y);
            rulesPanel.width = width - (Margin * 2f) - 15f;
            rulesPanel.height = height - y - Margin;
            rulesPanel.clipChildren = true;
            rulesPanel.autoLayout = true;
            rulesPanel.autoLayoutDirection = LayoutDirection.Vertical;
            rulesPanel.autoLayoutPadding = new RectOffset(0, 0, 0, (int)RuleGap);
            rulesPanel.scrollWheelDirection = UIOrientation.Vertical;
            rulesPanel.builtinKeyNavigation = true;
            UIScrollbars.AddScrollbar(this, rulesPanel);

            Populate();
        }

        // Rebuilds the rule groups from RuleSettings.Rules.
        private void Populate()
        {
            foreach (UIComponent child in new List<UIComponent>(rulesPanel.components))
            {
                rulesPanel.RemoveUIComponent(child);
                Destroy(child.gameObject);
            }

            Rule[] rules = RuleSettings.Rules;
            for (int i = 0; i < rules.Length; i++)
                AddRuleGroup(rules[i], i + 1);

            UIPanel buttonRow = rulesPanel.AddUIComponent<UIPanel>();
            buttonRow.width = rulesPanel.width;
            buttonRow.height = 40f;
            UIButton add = UIButtons.AddButton(buttonRow, 0f, 0f, Translations.Translate("ADD_RULE"), 250f);
            add.eventClicked += (c, p) =>
            {
                var list = new List<Rule>(RuleSettings.Rules) { new Rule() };
                RuleSettings.Set(list);
                Populate();
            };
        }

        private void AddRuleGroup(Rule rule, int number)
        {
            UIPanel group = rulesPanel.AddUIComponent<UIPanel>();
            group.width = rulesPanel.width;
            group.height = RuleHeight;
            group.atlas = UITextures.InGameAtlas;
            group.backgroundSprite = "GenericPanel";
            group.color = new Color32(160, 160, 170, 255);

            float x = 10f;
            float y = 8f;
            UILabels.AddLabel(group, x, y + 4f, string.Format(Translations.Translate("RULE_TITLE"), number), -1f, 1.0f);
            UIButton delete = UIButtons.AddSmallerButton(group, group.width - 170f, y, Translations.Translate("DELETE_RULE"), 160f);
            delete.eventClicked += (c, p) =>
            {
                var list = new List<Rule>(RuleSettings.Rules);
                list.Remove(rule);
                RuleSettings.Set(list);
                Populate();
            };
            y += 36f;

            UILabels.AddLabel(group, x, y, Translations.Translate("SOURCE"), -1f, 0.9f);
            y += 20f;
            AddSourceCheckBox(group, rule, x, y, SourceBuildingTypes.Industry, "SOURCE_INDUSTRY");
            AddSourceCheckBox(group, rule, x + Column, y, SourceBuildingTypes.Outside, "SOURCE_OUTSIDE");
            AddSourceCheckBox(group, rule, x + (Column * 2f), y, SourceBuildingTypes.Warehouse, "SOURCE_WAREHOUSE");
            y += 30f;

            UILabels.AddLabel(group, x, y, Translations.Translate("TARGET"), -1f, 0.9f);
            y += 20f;
            AddTargetCheckBox(group, rule, x, y, TargetBuildingTypes.Low, "TARGET_LOW", null);
            AddTargetCheckBox(group, rule, x + Column, y, TargetBuildingTypes.High, "TARGET_HIGH", null);
            AddTargetCheckBox(group, rule, x + (Column * 2f), y, TargetBuildingTypes.Eco, "TARGET_ECO", null);
            y += 24f;
            AddTargetCheckBox(group, rule, x, y, TargetBuildingTypes.Leisure, "TARGET_LEISURE", null);
            AddTargetCheckBox(group, rule, x + Column, y, TargetBuildingTypes.Tourist, "TARGET_TOURIST", null);
            AddTargetCheckBox(group, rule, x + (Column * 2f), y, TargetBuildingTypes.WallToWall, "TARGET_WALLTOWALL", "TARGET_WALLTOWALL_TOOLTIP");
            y += 32f;

            UICheckBox useSize = UICheckBoxes.AddLabelledCheckBox(group, x, y, Translations.Translate("CHECK_SIZE"), tooltip: Translations.Translate("CHECK_SIZE_TOOLTIP"));
            useSize.isChecked = rule.UseSize;
            y += 30f;

            UITextField length = UITextFields.AddSmallLabelledTextField(group, x + 260f, y, Translations.Translate("MAX_LENGTH"), 50f);
            UITextField widthField = UITextFields.AddSmallLabelledTextField(group, x + 260f + Column + 80f, y, Translations.Translate("MAX_WIDTH"), 50f);
            length.text = rule.MaxLength.ToString();
            widthField.text = rule.MaxWidth.ToString();
            SetSizeEnabled(length, widthField, rule.UseSize);

            useSize.eventCheckChanged += (c, isChecked) =>
            {
                rule.UseSize = isChecked;
                SetSizeEnabled(length, widthField, isChecked);
                RuleSettings.Save();
            };
            length.eventTextSubmitted += (c, text) =>
            {
                rule.MaxLength = ReadSize(length, rule.MaxLength);
                RuleSettings.Save();
            };
            widthField.eventTextSubmitted += (c, text) =>
            {
                rule.MaxWidth = ReadSize(widthField, rule.MaxWidth);
                RuleSettings.Save();
            };
        }

        private static void AddSourceCheckBox(UIComponent parent, Rule rule, float x, float y, SourceBuildingTypes type, string key)
        {
            UICheckBox box = UICheckBoxes.AddLabelledCheckBox(parent, x, y, Translations.Translate(key));
            box.isChecked = (rule.SourceBuildings & type) != 0;
            box.eventCheckChanged += (c, isChecked) =>
            {
                rule.SourceBuildings = isChecked ? rule.SourceBuildings | type : rule.SourceBuildings & ~type;
                RuleSettings.Save();
            };
        }

        private static void AddTargetCheckBox(UIComponent parent, Rule rule, float x, float y, TargetBuildingTypes type, string key, string tooltipKey)
        {
            UICheckBox box = UICheckBoxes.AddLabelledCheckBox(parent, x, y, Translations.Translate(key), tooltip: tooltipKey == null ? null : Translations.Translate(tooltipKey));
            box.isChecked = (rule.TargetBuildings & type) != 0;
            box.eventCheckChanged += (c, isChecked) =>
            {
                rule.TargetBuildings = isChecked ? rule.TargetBuildings | type : rule.TargetBuildings & ~type;
                RuleSettings.Save();
            };
        }

        private static void SetSizeEnabled(UITextField length, UITextField widthField, bool enabled)
        {
            length.isEnabled = enabled;
            widthField.isEnabled = enabled;
            length.opacity = enabled ? 1f : 0.5f;
            widthField.opacity = enabled ? 1f : 0.5f;
        }

        // Lot sizes in cells; zoned buildings are at most 4 x 4, other buildings can be larger.
        private static int ReadSize(UITextField field, int oldValue)
        {
            int value = int.TryParse(field.text, out int parsed) ? Mathf.Clamp(parsed, 1, 16) : oldValue;
            field.text = value.ToString();
            return value;
        }
    }
}

# frozen_string_literal: true

Unmagic::Components::Browser::Catalog.component :forms,
  name: "Form builder",
  group: "Forms",
  helper: "FormBuilder",
  import: nil,
  description: "The chrome around a form control — the wrapper, the label and its required marker, the hint " \
               "and the error line — and the look of the controls it builds, through config.control_class.",
  examples: [
    { key: :fields, title: "Fields", layout: :full,
      description: "field builds its control from as:, or takes one from a block; group lays fields out in a row." },
    { key: :states, title: "Invalid, disabled and read-only", layout: :full,
      description: "An attribute with errors marks its control aria-invalid and reads the errors underneath." },
    { key: :control_classes, title: "control_classes, outside a builder", layout: :full,
      description: "A select_tag or a hand-written input wears the same classes, sized to sit level with buttons." },
    { key: :switches, title: "Switches and sliders", layout: :full,
      description: "switch_field is a checkbox with role switch, drawn as one. range_field is the native slider " \
                   "styled to match." },
    { key: :choices, title: "Radio groups", layout: :full,
      description: "radio_button_collection in a fieldset named by legend:, with a hint under each option; " \
                   "variant: :cards makes the whole card the target." },
    { key: :secrets, title: "Passwords and one-time codes", layout: :full,
      description: "password_field reveal: true adds a button that shows what was typed. one_time_code_field " \
                   "is one real input drawn as a row of boxes, so paste and autofill just work. Needs " \
                   "import \"unmagic/components/password\" and \"unmagic/components/one_time_code\"." },
    { key: :input_groups, title: "Input groups", layout: :full,
      description: "input_group joins a unit, a scheme, an icon or a button to either end of a control." },
    { key: :autogrow, title: "Autogrowing textarea", layout: :full,
      description: "Grows from its rows up to its max-height, then scrolls. Needs import \"unmagic/components/autogrow\"." },
    { key: :uuid_field, title: "UUID field", layout: :full,
      description: "A hidden field holding a fresh UUIDv7, minted again when the element upgrades and on every " \
                   "form reset. Needs import \"unmagic/components/uuid_input\"." }
  ]

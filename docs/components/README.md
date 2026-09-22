# Component design notes

One note per component, written and reviewed **before** the component is built.
Each follows [`_template.md`](_template.md) and is held to the
[design principles](../design-principles.md).

The first round of components comes from comparing the gem with the Rails Blocks
catalogue. Rails Blocks was used only as a list of what's missing; every design
here is original to this gem.

The second round is the [AI chat components](ai_chat/README.md), drawn from three
applications that each grew their own agent UI and largely converged, and
measured against assistant-ui's primitive vocabulary. Those notes live in
[`ai_chat/`](ai_chat/README.md); the generic elements they need are filed here with
everything else.

Status is `draft` until reviewed, then `reviewed`, then `built`.

## Already shipped

These are documented in the README and have no notes here:
- `table_for`, `row_for`, `table_tag`
- `detail_list`
- `FormBuilder`
- `toggle`, `toggle_group`, `input_group`, `range_field`, `section`, `item`, `chart`, `button`, `button_group`, `button_classes`, `badge`, `callout`, `card`, `page_header`, `empty_state`, `panel`, `separator`, `progress`, `code_view`
- skeletons
- `modal_frame`, `dialog`, `dialog_tag`, the confirm dialog
- `flash_toasts`
- `local_time_tag`, `tooltip`, `menu`, `tabs`, `copy_button`
- `autogrow_text_area`, `uuid_field`

## Tier 1: markup and CSS

| Note | Rails Blocks gap | Status |
|---|---|---|
| [avatar](avatar.md) | Avatar | built |
| [breadcrumbs](breadcrumbs.md) | Breadcrumb | built |
| [kbd](kbd.md) | KBD & Hotkey (the key hint) | built |
| [spinner](spinner.md) | Loading Indicator | built |
| [steps](steps.md) | Stepper | draft |
| [timeline](timeline.md) | (none) ReUI Timeline: a history of events joined by a line | built |
| [accordion](accordion.md) | Accordion, Collapsible | built |
| [tree_view](tree_view.md) | Tree View | built |
| [banner](banner.md) | Banner | draft |
| [switch_field](switch_field.md) | Switch | built |
| [radio_button_collection](radio_button_collection.md) | Radio | built |

## Tier 2: small custom elements

| Note | Rails Blocks gap | Status |
|---|---|---|
| [bulk_select](bulk_select.md) | Checkbox Select All | draft |
| [drawer](drawer.md) | Drawer, Slideover | built |
| [popover](popover.md) | Popover | built |
| [password_field](password_field.md) | Password | built |
| [one_time_code_field](one_time_code_field.md) | Two Factor | built |
| [infinite_scroll](infinite_scroll.md) | Infinite Scroll | draft |
| [sidebar](sidebar.md) | Sidebar | built |
| [context_menu](context_menu.md) | Context Menu | built |
| [animated_number](animated_number.md) | Animated Number | draft |
| [hotkey](hotkey.md) | KBD & Hotkey (the shortcut) | draft |
| [sortable_list](sortable_list.md) | (none) drag-and-drop ordering, extracted from hooops | built |
| [board](board.md) | (none) a Trello-style board on sortable lists | built |
| [position](position.md) | (infrastructure) shared placement and `menu` on the Popover API | built |
| [auto_scroll](auto_scroll.md) | (none) `<unmagic-autoscroll>`, extracted from hooops and toybox | built |
| [optimistic](optimistic.md) | (none) `<unmagic-optimistic>`, the client half of the `upsert` contract | built |
| [elapsed](elapsed.md) | (none) `<unmagic-elapsed>`, a clock counting up from a server-named moment | built |

## Tier 3: large or dependency-heavy

| Note | Rails Blocks gap | Status |
|---|---|---|
| [combobox](combobox.md) | Combobox (Multi-select), Autocomplete | built |
| [command_palette](command_palette.md) | Command Palette | built |
| [carousel](carousel.md) | Carousel | draft |
| [lightbox](lightbox.md) | Lightbox | draft |
| [date_picker](date_picker.md) | Date Picker | draft |
| [color_picker](color_picker.md) | Color Picker | draft |
| [emoji_picker](emoji_picker.md) | Emoji Picker | draft |

## Marketing, and the rest

Where marketing-style components belong is open decision 2 in the principles.

| Note | Rails Blocks gap | Status |
|---|---|---|
| [navbar](navbar.md) | Navbar | built |
| [dark_mode_switcher](dark_mode_switcher.md) | Dark Mode Switcher | draft |
| [scroll_area](scroll_area.md) | Scroll Area | built |
| [select](select.md) | Select | draft |
| [onboarding_checklist](onboarding_checklist.md) | Onboarding Checklist | draft |
| [feedback](feedback.md) | Feedback | draft |
| [dock](dock.md) | Dock Menu | draft |
| [marquee](marquee.md) | Marquee | draft |
| [testimonial](testimonial.md) | Testimonial | draft |

## AI chat components

A family of its own, with its own index and its own decisions:
[`ai_chat/README.md`](ai_chat/README.md). It covers the transcript, messages, the
streamed reveal, tool calls, the composer, plans, workspaces, and the components
for an agent that stops to ask something — permission gates, questions and
inline proposals.

## Covered by existing components

| Rails Blocks | Here |
|---|---|
| Alert | `callout` |
| Autogrow | `autogrow_text_area` |
| Badge | `badge` |
| Buttons | `button_classes` |
| Card | `card` |
| Checkbox | `FormBuilder#check_box_field`, `#check_box_collection` |
| Clipboard | `copy_button` |
| Confirmation | the confirm dialog |
| Datatable, Table | `table_for`, `table_tag` |
| Dropdown | `menu` |
| Forms | `FormBuilder` |
| Modal | `modal_frame`, `dialog`, `dialog_tag` |
| Pagination | `pagination`, and the pagination seam |
| Skeleton | `skeleton` |
| Tabs | `tabs` |
| Toast | `flash_toasts`, `turbo_stream.toast` |
| Tooltip | `tooltip` |

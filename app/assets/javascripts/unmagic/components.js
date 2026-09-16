// Every component's behaviour in one import:
//
//   import "unmagic/components"
//
// This also installs the confirm dialog in place of window.confirm, and it needs
// Turbo. An app that wants only some components, or has no Turbo, imports those
// modules by name instead (import "unmagic/components/tooltip").
import "unmagic/components/upsert"
import "unmagic/components/dialog"
import "unmagic/components/modal"
import "unmagic/components/confirm"
import "unmagic/components/toasts"
import "unmagic/components/time"
import "unmagic/components/tooltip"
import "unmagic/components/menu"
import "unmagic/components/tabs"
import "unmagic/components/clipboard"
import "unmagic/components/autogrow"
import "unmagic/components/uuid_input"
import "unmagic/components/elapsed"
import "unmagic/components/autoscroll"
import "unmagic/components/optimistic"
import "unmagic/components/streaming_markdown"
import "unmagic/components/toolbar"
import "unmagic/components/slash_menu"
import "unmagic/components/dropzone"
import "unmagic/components/ai_chat"
import "unmagic/components/sortable"
import "unmagic/components/board"

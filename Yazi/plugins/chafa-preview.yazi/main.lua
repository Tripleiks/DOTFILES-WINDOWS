-- chafa-preview.yazi/main.lua
--
-- Image previewer that shells out to `chafa` for ANSI/Unicode-block rendering.
--
-- Why this exists:
--   Yazi auto-picks the image preview driver from the terminal's DA1
--   capability response. Windows Terminal v1.22+ advertises Sixel support
--   in DA1, so yazi picks the sixel driver - but WT's sixel implementation
--   does not visibly render in yazi's preview pane (the data is emitted
--   but not painted). There is no env var or config key in v26.x to
--   override yazi's driver choice; the only escape hatch is a custom
--   previewer registered via [[plugin.prepend_previewers]] in yazi.toml,
--   which intercepts image/* before the built-in image plugin runs.
--
-- This plugin is wired up in Yazi/config/yazi.toml:
--   [[plugin.prepend_previewers]]
--   mime = "image/*"
--   run  = "chafa-preview"
--
-- Requires: chafa (>= 1.16.0) on PATH. Installed by PowerShell/setup.ps1
-- (winget id hpjansson.Chafa).
--
-- API target: yazi v26.5.6 plugin API
--   - Command(...):arg({...}):output() returns (output, err)
--   - ya.preview_widget (singular) - the plural form is the older v25 API
--   - tostring(job.file.path) for the absolute path

local M = {}

function M:peek(job)
	local size = string.format("%dx%d", job.area.w, job.area.h)
	local output, err = Command("chafa")
		:arg({
			"-f", "symbols",      -- output format: unicode block symbols + ANSI color
			"--animate", "off",   -- do not run animations in the preview pane
			"-s", size,           -- size in terminal cells (matches the preview pane)
			tostring(job.file.path),
		})
		:output()

	local text
	if output then
		text = ui.Text.parse(output.stdout)
	else
		text = ui.Text("Failed to start chafa: " .. tostring(err))
	end

	ya.preview_widget(job, text:area(job.area))
end

function M:seek() end

return M

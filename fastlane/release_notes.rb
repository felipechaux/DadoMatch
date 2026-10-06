# frozen_string_literal: true

# Store release notes ("What's new") written from the commits of a release.
#
# Commits from this repo since the previous vX.Y.Z tag, plus the shared KMP
# repo since the shared commit that release was built from, are rewritten for
# end users by the Claude CLI. The result is saved as JSON next to the release
# (fastlane/release_notes/vX.Y.Z.json), reviewed by a human before upload, and
# committed with the version bump.
#
# Kept identical in DadoMatch (Android) and DadoMatch-ios.

require "json"
require "open3"
require "fileutils"

module ReleaseNotes
  # Languages generated, as Google Play codes; App Store mapping lives in the iOS Fastfile
  LANGUAGES = %w[en-US es-419].freeze
  MAX_CHARS = 500 # Google Play limit (App Store allows 4000)
  NOTES_DIR = File.expand_path("release_notes", __dir__)
  SHARED_TRAILER = "Shared"
  TRAILER = /\A(Co-Authored-By|Signed-off-by|#{SHARED_TRAILER}): /i

  module_function

  def path_for(tag)
    File.join(NOTES_DIR, "#{tag}.json")
  end

  def load(tag)
    path = path_for(tag)
    UI.user_error!("No release notes for #{tag} at #{path}") unless File.exist?(path)
    JSON.parse(File.read(path))
  end

  # Latest release tag reachable from HEAD, or nil on the first release
  def previous_tag(repo)
    out, status = Open3.capture2("git", "-C", repo, "describe", "--tags", "--abbrev=0", "--match", "v[0-9]*")
    status.success? ? out.strip : nil
  end

  # "Shared: <sha>" trailer the release lanes write into the tag message
  def tag_trailer_line(shared_sha)
    "#{SHARED_TRAILER}: #{shared_sha}"
  end

  # Commits worth telling users about since the previous release, from both repos
  def collect_commits(app_repo:, shared_repo:, previous_tag:)
    app_range = previous_tag ? ["#{previous_tag}..HEAD"] : ["-20", "HEAD"]
    shared_args =
      if previous_tag && (shared_sha = shared_sha_of(app_repo, previous_tag))
        ["#{shared_sha}..HEAD"]
      elsif previous_tag
        # Tags created before the trailer existed: fall back to the tag date
        ["--since=#{git(app_repo, 'log', '-1', '--format=%cI', previous_tag)}", "HEAD"]
      else
        ["-20", "HEAD"]
      end
    log(app_repo, app_range) + log(shared_repo, shared_args)
  end

  # Returns { "en-US" => "• ...", "es-419" => "• ..." }
  def generate(platform:, commits:)
    return fallback if commits.empty?

    prompt = <<~PROMPT
      You write app store release notes. Below are the git commits that went into a new
      version of DadoMatch (an AI icebreaker / dating-opener app) for #{platform.upcase}.
      Write the "What's new" text for end users:
      - Only user-visible changes on #{platform}. Ignore changes specific to other platforms,
        CI, build, release tooling, refactors and internal fixes users can't notice.
      - 3 to 5 bullets, each starting with "• ", short and friendly, no jargon, no commit
        prefixes, no PR numbers.
      - If there is nothing user-visible, use a single "• Bug fixes and performance improvements".
      - At most #{MAX_CHARS - 50} characters per language.
      Return ONLY a JSON object, no code fences: {"en-US": "...", "es-419": "..."}
      where es-419 is natural Latin American Spanish.
    PROMPT

    # Use the developer's claude.ai login: an exported API key would take precedence
    env = { "ANTHROPIC_API_KEY" => nil }
    out, err, status = Open3.capture3(env, "claude", "-p", prompt, stdin_data: commits.join("\n"))
    unless status.success?
      UI.important("Claude CLI failed (#{err.strip.lines.last}); using generic notes — edit them in the review step")
      return fallback
    end

    notes = JSON.parse(out[/\{.*\}/m] || "")
    LANGUAGES.to_h { |lang| [lang, notes.fetch(lang).strip] }
  rescue JSON::ParserError, KeyError, Errno::ENOENT => e
    UI.important("Could not generate release notes (#{e.class}); using generic notes — edit them in the review step")
    fallback
  end

  # Shows the notes and waits for approval; the file can be edited meanwhile
  def review!(tag, purpose:)
    path = path_for(tag)
    loop do
      notes = JSON.parse(File.read(path))
      too_long = notes.select { |_, text| text.length > MAX_CHARS }.keys
      UI.header("Release notes #{tag} — #{purpose}")
      notes.each { |lang, text| UI.message("[#{lang}] (#{text.length}/#{MAX_CHARS})\n#{text}\n") }
      UI.important("Over #{MAX_CHARS} characters: #{too_long.join(', ')}") unless too_long.empty?

      case UI.select("Edit #{path} if needed, then:", ["Use these notes", "Reload after editing", "Abort"])
      when "Use these notes"
        return notes if too_long.empty?
        UI.error("Shorten #{too_long.join(', ')} first")
      when "Abort"
        UI.user_error!("Release notes not approved")
      end
    end
  end

  def save(tag, notes)
    FileUtils.mkdir_p(NOTES_DIR)
    File.write(path_for(tag), JSON.pretty_generate(notes) + "\n")
  end

  def fallback
    {
      "en-US" => "• Bug fixes and performance improvements",
      "es-419" => "• Corrección de errores y mejoras de rendimiento"
    }
  end

  def shared_sha_of(repo, tag)
    message = git(repo, "tag", "-l", "--format=%(contents)", tag)
    message[/^#{SHARED_TRAILER}: (\h{7,40})$/, 1]
  end

  # Subject + body of user-facing commits (feat/fix/perf), without trailers
  def log(repo, args)
    raw = git(repo, "log", "--no-merges", "--format=%s%n%b%x1e", *args)
    raw.split("\x1e").map(&:strip).reject(&:empty?)
       .select { |c| c.match?(/\A(feat|fix|perf)(\(.+?\))?!?:/) }
       .map { |c| c.lines.reject { |l| l.strip.match?(TRAILER) }.join.strip }
  end

  def git(repo, *args)
    out, status = Open3.capture2("git", "-C", repo, *args)
    UI.user_error!("git #{args.join(' ')} failed in #{repo}") unless status.success?
    out.strip
  end
end

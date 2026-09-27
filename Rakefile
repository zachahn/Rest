# Rest release pipeline, adapted from ../Plunger/Rakefile.
#
# rake notary_setup APPLE_ID=you@example.com
# rake bump VERSION=1.1
# rake release
#
# Tasks also run independently:
# release:preflight, release:archive, release:export, release:zip,
# release:notarize, release:appcast, release:github.
#
# rake release publishes a regular release and marks it latest, activating
# https://github.com/zachahn/Rest/releases/latest/download/appcast.xml.
# Commit and push source changes before publishing so the release tag can target
# the matching commit. This pipeline does not commit or push automatically.
#
# Optional local overrides go in gitignored release.json or environment variables.
# Credentials and the Sparkle private key stay in Keychain. Defaults below match
# this app; APPLE_ID is needed only when creating new notarization credentials.
# BUILD_DIR can point at an existing distribution directory to resume a build.

require "shellwords"
require "fileutils"
require "json"
require "digest"
require "rexml/document"

RELEASE_CONFIG =
  begin
    path = File.join(__dir__, "release.json")
    File.exist?(path) ? JSON.parse(File.read(path)) : {}
  end

def setting(key, default = nil)
  ENV[key] || RELEASE_CONFIG[key] || default ||
    abort("missing #{key} — set it in release.json or pass #{key}=... on the command line")
end

WORKSPACE      = setting("WORKSPACE", "Rest.xcworkspace")
SCHEME         = setting("SCHEME", "Rest")
CONFIGURATION  = setting("CONFIGURATION", "Release")
NOTARY_PROFILE = setting("NOTARY_PROFILE", "cody")
TEAM_ID        = setting("TEAM_ID", "TZWTJP2JSN")
GH_REPO        = setting("GH_REPO", "zachahn/Rest")
SPARKLE_ACCOUNT = setting("SPARKLE_ACCOUNT", "com.zachahn.Rest")

ROOT       = __dir__
BUILD_DIR  = File.expand_path(setting("BUILD_DIR", "build"), ROOT)
ARCHIVE    = File.join(BUILD_DIR, "Rest.xcarchive")
EXPORT_DIR = File.join(BUILD_DIR, "export")
APP        = File.join(EXPORT_DIR, "Rest.app")
DIST_DIR   = File.join(BUILD_DIR, "dist")
APPCAST    = File.join(DIST_DIR, "appcast.xml")
MANIFEST   = File.join(ROOT, "Project.swift")
Dir.chdir(ROOT)

# ---- helpers ---------------------------------------------------------------

# ANSI SGR color codes, named so the tasks below read as ok/warn/halt/step
# instead of raw \e[..m sequences.
GREEN  = 32 # success lines
YELLOW = 33 # caution lines
RED    = 31 # failure messages
CYAN   = 36 # step banners and echoed commands

# Wrap the string in an ANSI color and reset. One place for the escape codes.
class String
  def colorize(number) = "\e[#{number}m#{self}\e[0m"
end

def ok(text)   = puts "✓ #{text}".colorize(GREEN)  # green success line
def warn(text) = puts text.colorize(YELLOW)        # yellow caution line
def note(text) = puts "  #{text}"                  # plain, indented secondary hint
def halt(text) = abort text.colorize(RED)          # red message, then abort the run

# Print a cyan banner announcing the step about to run.
def step(text) = puts "\n▶ #{text}".colorize(CYAN)

# Run a command, echoing it first. Raises (aborting the rake run) on failure.
def sh!(*args)
  puts "$ #{args.map { |a| Shellwords.escape(a) }.join(" ")}".colorize(CYAN)
  system(*args) || halt("command failed: #{args.first}")
end

# Capture stdout of a command, aborting on failure.
def capture!(*args)
  out = IO.popen(args, &:read)
  halt("command failed: #{args.first}") unless $?.success?
  out
end

# Read a build-setting value from the exported .app's Info.plist.
def plist(key)
  halt("missing #{APP} — run `rake release:export` first") unless File.exist?(APP)
  capture!("/usr/libexec/PlistBuddy", "-c", "Print :#{key}", File.join(APP, "Contents", "Info.plist")).strip
end

def marketing_version = plist("CFBundleShortVersionString") # e.g. 1.1
def build_version     = plist("CFBundleVersion")            # e.g. 6  (Sparkle's sparkle:version)
def tag               = "v#{marketing_version}"
def zip_name          = "Rest-#{marketing_version}-#{build_version}.zip"
def zip_path          = File.join(DIST_DIR, zip_name)
def download_prefix   = "https://github.com/#{GH_REPO}/releases/download/#{tag}/"

# Tuist resolves Sparkle and its tools here, pinned by Package.resolved.
def sparkle_bin_dir
  File.join(ROOT, "Tuist/.build/artifacts/sparkle/Sparkle/bin")
end

def generate_appcast_bin
  dir = sparkle_bin_dir
  path = dir && File.join(dir, "generate_appcast")
  halt("generate_appcast not found — run `tuist install` first") unless path && File.exist?(path)
  path
end

def notary_profile_exists?
  # `notarytool history` succeeds only if the named keychain profile resolves.
  system("xcrun", "notarytool", "history", "--keychain-profile", NOTARY_PROFILE,
         out: File::NULL, err: File::NULL)
end

# ---- tasks -----------------------------------------------------------------

desc "One-time: save a notarytool keychain profile (prompts for an app-specific password)"
task :notary_setup do
  if notary_profile_exists?
    ok "notarytool profile \"#{NOTARY_PROFILE}\" already exists — nothing to do"
    next
  end

  apple_id = setting("APPLE_ID")
  puts "Creating notarytool profile \"#{NOTARY_PROFILE}\" for #{apple_id} (team #{TEAM_ID})."
  puts "Generate an app-specific password at https://appleid.apple.com → Sign-In and Security."
  # Omitting --password makes notarytool prompt for it, so the secret is typed
  # straight into store-credentials and never passes through this task or the
  # shell history.
  sh! "xcrun", "notarytool", "store-credentials", NOTARY_PROFILE,
      "--apple-id", apple_id,
      "--team-id", TEAM_ID
  ok "profile \"#{NOTARY_PROFILE}\" saved; `rake release:notarize` can now notarize"
end

desc "Bump the marketing version (VERSION=x.y) and increment the build number"
task :bump do
  version = ENV["VERSION"]
  halt("set VERSION, e.g. `rake bump VERSION=1.1`") if version.to_s.strip.empty?
  halt("VERSION must look like 1.1 or 1.2.3") unless version.match?(/\A\d+(\.\d+){1,2}\z/)

  # Project.swift is authoritative; Tuist regenerates the Xcode project.
  text = File.read(MANIFEST)
  builds = text.scan(/"CURRENT_PROJECT_VERSION": "(\d+)"/).flatten.map(&:to_i)
  halt("no CURRENT_PROJECT_VERSION found in Project.swift") if builds.empty?
  halt("no MARKETING_VERSION found in Project.swift") unless text.match?(/"MARKETING_VERSION": "[^"]+"/)
  next_build = builds.max + 1
  text = text.gsub(/"CURRENT_PROJECT_VERSION": "\d+"/, %Q("CURRENT_PROJECT_VERSION": "#{next_build}"))
  text = text.gsub(/"MARKETING_VERSION": "[^"]+"/, %Q("MARKETING_VERSION": "#{version}"))
  File.write(MANIFEST, text)
  ok "marketing version #{version}, build #{next_build}"
  note "Review and commit Project.swift before releasing."

end

desc "Full release: preflight → archive → export → zip → notarize → appcast → GitHub publish"
task release: %w[
  release:preflight
  release:archive
  release:export
  release:zip
  release:notarize
  release:appcast
  release:github
] do
  ok "release #{tag} published"
end

namespace :release do
  desc "check that the tools, keys, and repo state a release needs are in place"
  task :preflight do
    step "preflight — checking the release environment"

    # Collect every problem, then report them together, so one `rake release`
    # surfaces all the fixes at once instead of failing on the first missing key.
    problems = []
    ask = ->(label, ok_cond) { ok_cond ? ok(label) : (problems << label) }

    sh! "tuist", "install"

    # xcodebuild for archive/export.
    ask.("xcodebuild present",
         system("xcodebuild", "-version", out: File::NULL, err: File::NULL))

    # Sparkle tools (generate_appcast for the appcast, generate_keys to read the
    # EdDSA key) land in DerivedData once the app has built and SPM resolved.
    bin = sparkle_bin_dir
    ask.("Sparkle tools resolved (build the app once so SPM fetches Sparkle)",
         bin && File.exist?(File.join(bin, "generate_appcast")))

    # The appcast is signed with the EdDSA private key in the Keychain.
    # generate_keys -p prints the public key and exits 0 only if the key exists.
    keys = bin && File.join(bin, "generate_keys")
    ask.("Sparkle EdDSA signing key in Keychain (run `#{keys || "generate_keys"} --account #{SPARKLE_ACCOUNT}` once)",
         keys && File.exist?(keys) &&
           system(keys, "--account", SPARKLE_ACCOUNT, "-p", out: File::NULL, err: File::NULL))

    # notarytool keychain profile for the notarize step.
    ask.("notarytool profile \"#{NOTARY_PROFILE}\" saved (run `rake notary_setup`)",
         notary_profile_exists?)

    # gh authenticated for creating the GitHub release.
    ask.("gh authenticated (run `gh auth login`)",
         system("gh", "auth", "status", out: File::NULL, err: File::NULL))

    # Managed Developer ID signing usually can't be listed on the CLI, so a
    # missing cert here is a heads-up, not a failure — the export may still work.
    unless system("sh", "-c",
                  "security find-identity -v -p codesigning | grep -q 'Developer ID Application'",
                  out: File::NULL, err: File::NULL)
      warn "  ⚠ no 'Developer ID Application' cert listed on the CLI — fine if Xcode manages signing, but export will fail if it truly can't sign"
    end

    halt("preflight found problems:\n  - #{problems.join("\n  - ")}") unless problems.empty?
    ok "preflight passed — the release environment looks ready"
  end

  desc "archive the app (xcodebuild archive)"
  task :archive do
    step "archiving the app"
    FileUtils.mkdir_p(BUILD_DIR)
    FileUtils.rm_rf(ARCHIVE)
    sh! "tuist", "install"
    sh! "tuist", "generate", "--no-open"
    sh! "tuist", "xcodebuild", "archive",
        "-workspace", WORKSPACE,
        "-scheme", SCHEME,
        "-configuration", CONFIGURATION,
        "-destination", "generic/platform=macOS",
        "-archivePath", ARCHIVE,
        "-derivedDataPath", File.join(BUILD_DIR, "DerivedData"),
        "ARCHS=arm64 x86_64", "ONLY_ACTIVE_ARCH=NO"
    ok "archived → #{ARCHIVE}"
  end

  desc "export a Developer ID-signed .app from the archive"
  task :export do
    step "exporting a Developer ID-signed .app"
    halt("missing archive — run `rake release:archive` first") unless File.exist?(ARCHIVE)
    FileUtils.rm_rf(EXPORT_DIR)

    # method=developer-id reuses Xcode's managed Developer ID signing, so this
    # works even when `security find-identity` can't list the cert on the CLI.
    options = File.join(BUILD_DIR, "ExportOptions.plist")
    File.write(options, <<~PLIST)
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
          <key>method</key><string>developer-id</string>
          <key>signingStyle</key><string>automatic</string>
          <key>teamID</key><string>#{TEAM_ID}</string>
          <key>signingCertificate</key><string>Developer ID Application</string>
      </dict>
      </plist>
    PLIST

    # Tuist does not support the export action.
    sh! "xcodebuild", "-exportArchive",
        "-archivePath", ARCHIVE,
        "-exportPath", EXPORT_DIR,
        "-exportOptionsPlist", options
    halt("export did not produce #{APP}") unless File.exist?(APP)
    sh! "codesign", "--verify", "--deep", "--strict", "--verbose=2", APP
    ok "exported → #{APP} (#{marketing_version}, build #{build_version})"
  end

  desc "zip the exported .app for distribution"
  task :zip do
    step "zipping the .app"
    halt("missing #{APP} — run `rake release:export` first") unless File.exist?(APP)
    FileUtils.mkdir_p(DIST_DIR)
    FileUtils.rm_f(zip_path)
    # ditto preserves the bundle's symlinks/metadata; Sparkle expects a clean zip.
    sh! "ditto", "-c", "-k", "--sequesterRsrc", "--keepParent", APP, zip_path
    ok "zipped → #{zip_path}"
  end

  desc "notarize the zip with notarytool and staple the .app"
  task :notarize do
    step "notarizing and stapling"
    halt("missing #{zip_path} — run `rake release:zip` first") unless File.exist?(zip_path)

    halt("No notarytool profile #{NOTARY_PROFILE.inspect}; run `rake notary_setup APPLE_ID=...`.") unless notary_profile_exists?
    result = capture!("xcrun", "notarytool", "submit", zip_path,
                      "--keychain-profile", NOTARY_PROFILE, "--wait", "--output-format", "json")
    File.write(File.join(BUILD_DIR, "notarization.json"), result)
    submission = JSON.parse(result)
    halt("Notarization #{submission['status']}; use `xcrun notarytool log #{submission['id']} --keychain-profile #{NOTARY_PROFILE}`.") unless submission["status"] == "Accepted"
    # Staple the ticket onto the .app, then re-zip so the distributed zip carries it.
    sh! "xcrun", "stapler", "staple", APP
    sh! "xcrun", "stapler", "validate", APP
    FileUtils.rm_f(zip_path)
    sh! "ditto", "-c", "-k", "--sequesterRsrc", "--keepParent", APP, zip_path
    sh! "codesign", "--verify", "--deep", "--strict", "--verbose=2", APP
    sh! "spctl", "--assess", "--type", "execute", "--verbose=2", APP
    File.write("#{zip_path}.sha256", "#{Digest::SHA256.file(zip_path).hexdigest}  #{zip_name}\n")
    ok "notarized + stapled; re-zipped → #{zip_path}"
  end

  desc "generate/update the EdDSA-signed appcast.xml for this version"
  task :appcast do
    step "generating the signed appcast.xml"
    halt("missing #{zip_path} — run earlier steps first") unless File.exist?(zip_path)

    sh! "xcrun", "stapler", "validate", APP
    public_key = capture!(File.join(sparkle_bin_dir, "generate_keys"), "--account", SPARKLE_ACCOUNT, "-p").strip
    halt("Sparkle Keychain key does not match the app's public key") unless public_key == plist("SUPublicEDKey")
    expected_feed = "https://github.com/#{GH_REPO}/releases/latest/download/appcast.xml"
    halt("App feed URL does not match GH_REPO") unless plist("SUFeedURL") == expected_feed

    sh! generate_appcast_bin,
        "--account", SPARKLE_ACCOUNT,
        "--versions", build_version,
        "--maximum-deltas", "0",
        "--download-url-prefix", download_prefix,
        "-o", APPCAST,
        DIST_DIR
    ok "appcast.xml updated for #{marketing_version} (build #{build_version})"
    note "enclosure URL prefix: #{download_prefix}"
  end

  desc "publish a regular GitHub release with the ZIP, checksum, and appcast"
  task :github do
    step "publishing the GitHub release"
    halt("missing ZIP or appcast — run earlier steps first") unless File.exist?(zip_path) && File.exist?(APPCAST)
    document = REXML::Document.new(File.read(APPCAST))
    item = REXML::XPath.match(document, "/rss/channel/item").find do |entry|
      entry.elements["sparkle:version"]&.text == build_version
    end
    enclosure = item&.elements&.[]("enclosure")
    halt("Appcast does not describe this ZIP") unless enclosure &&
      enclosure.attributes["url"] == "#{download_prefix}#{zip_name}" &&
      enclosure.attributes["length"].to_i == File.size(zip_path)
    sh! File.join(sparkle_bin_dir, "sign_update"), "--account", SPARKLE_ACCOUNT,
        "--verify", zip_path, enclosure.attributes["sparkle:edSignature"]
    Dir.chdir(DIST_DIR) { sh! "shasum", "-a", "256", "-c", "#{zip_name}.sha256" }

    # Stage assets in a draft so the feed becomes public only after upload succeeds.
    # Existing public assets must stay immutable; reruns may replace draft assets.
    releases = JSON.parse(capture!("gh", "api", "--paginate", "repos/#{GH_REPO}/releases", "--slurp")).flatten
    existing = releases.find { |release| release["tag_name"] == tag }
    assets = [zip_path, "#{zip_path}.sha256", APPCAST]
    if existing
      halt("#{tag} is already published; bump the version first") unless existing["draft"]
      sh! "gh", "release", "upload", tag, *assets, "--repo", GH_REPO, "--clobber"
    else
      notes = File.join(BUILD_DIR, "release-notes.md")
      File.write(notes, <<~NOTES)
        Rest #{marketing_version} (build #{build_version}) for macOS 14 or later.

        - Universal app for Apple silicon and Intel Macs.
        - Developer ID signed and notarized by Apple.
        - Sparkle updates with a Check for Updates menu item.

        Download #{zip_name}, unzip it, and move Rest.app to Applications.
      NOTES
      sh! "gh", "release", "create", tag, *assets,
          "--repo", GH_REPO, "--draft",
          "--title", "Rest #{marketing_version}", "--notes-file", notes
    end
    sh! "gh", "release", "edit", tag, "--repo", GH_REPO,
        "--draft=false", "--prerelease=false", "--latest"
    ok "GitHub release #{tag} published with #{zip_name} and appcast.xml"
    note "Sparkle feed: https://github.com/#{GH_REPO}/releases/latest/download/appcast.xml"
  end

end

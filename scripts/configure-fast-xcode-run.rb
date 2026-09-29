#!/usr/bin/env ruby
# 使用 xcodeproj 安全调整工程结构：普通 iPhone Run 不再构建 / 嵌入 Watch App，
# Archive 仍通过 iFinance Scheme 显式构建 Watch App，并在部署后处理阶段嵌入。

require "xcodeproj"

project_path = File.expand_path("../iFinance.xcodeproj", __dir__)
project = Xcodeproj::Project.open(project_path)

app_target = project.targets.find { |target| target.name == "iFinance" }
watch_target = project.targets.find { |target| target.name == "WatchiFinance Watch App" }
abort "未找到 iFinance / WatchiFinance Watch App target" unless app_target && watch_target

app_target.dependencies
    .select { |dependency| dependency.target == watch_target }
    .each(&:remove_from_project)

embed_phase = app_target.copy_files_build_phases.find { |phase| phase.name == "Embed Watch Content" }
abort "未找到 Embed Watch Content 构建阶段" unless embed_phase

embed_phase.run_only_for_deployment_postprocessing = "1"

# Scheme 在 Archive 时按「Watch → iPhone」手动顺序构建，日常 Run 则只启用 iPhone。
# 这是为了表达「只在 Archive 需要的依赖」，关闭 Xcode 的通用弃用提示。
project.build_configurations.each do |configuration|
  configuration.build_settings["DISABLE_MANUAL_TARGET_ORDER_BUILD_WARNING"] = "YES"
end

project.save

puts "已配置：普通 Run 跳过 Watch，Archive 保留 Watch 嵌入。"

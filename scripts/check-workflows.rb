#!/usr/bin/env ruby
# frozen_string_literal: true

# Controlla la coerenza interna dei workflow: ogni job elencato in `needs` deve
# esistere, e ogni `needs.<job>.result` usato in `if`/`env` deve essere fra i
# `needs` dichiarati.
#
# Serve perché un riferimento a un job cancellato NON è un errore visibile: il
# workflow diventa invalido e GitHub registra un run "failure" senza nessun job,
# senza log utili. È già successo togliendo il job `shellcheck` e lasciando il
# riferimento nel job `report`.
#
#   scripts/check-workflows.rb [file.yml ...]   # default: .github/workflows/*.yml

require "yaml"

files = ARGV.empty? ? Dir[".github/workflows/*.yml"].sort : ARGV
abort("check-workflows: nessun workflow da controllare") if files.empty?

problems = []

files.each do |file|
  workflow = begin
    YAML.safe_load(File.read(file), aliases: true)
  rescue Psych::SyntaxError => e
    problems << "#{file}: YAML non valido — #{e.message}"
    next
  end

  jobs = workflow.is_a?(Hash) ? workflow["jobs"] : nil
  unless jobs.is_a?(Hash) && !jobs.empty?
    problems << "#{file}: nessun job"
    next
  end

  jobs.each do |name, job|
    declared = Array(job["needs"])
    declared.each do |dep|
      problems << "#{file}: il job '#{name}' dipende da '#{dep}', che non esiste" unless jobs.key?(dep)
    end

    # needs.foo.result e needs['foo'].result, ovunque nel job (if, env, run).
    dumped = job.to_s
    used = dumped.scan(/needs\.([A-Za-z0-9_-]+)\.result/).flatten +
           dumped.scan(/needs\[['"]([A-Za-z0-9_-]+)['"]\]\.result/).flatten
    used.uniq.each do |dep|
      problems << "#{file}: il job '#{name}' legge needs.#{dep}.result ma non esiste" unless jobs.key?(dep)
      problems << "#{file}: il job '#{name}' legge needs.#{dep}.result senza dichiararlo in needs" unless declared.include?(dep)
    end
  end

  puts "#{file}: #{jobs.size} job (#{jobs.keys.join(', ')})"
end

unless problems.empty?
  warn ""
  problems.each { |p| warn "::error::#{p}" }
  exit 1
end

puts "riferimenti tra job coerenti"

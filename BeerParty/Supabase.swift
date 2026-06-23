//
//  Supabase.swift
//  BeerParty
//
//  Created by Aksel Paul on 2/9/26.
//
import Foundation
import Supabase

private func requiredConfigValue(for key: String) -> String {
  if let envValue = ProcessInfo.processInfo.environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines),
     !envValue.isEmpty,
     !envValue.contains("$(")
  {
    return envValue
  }

  if let plistValue = Bundle.main.object(forInfoDictionaryKey: key) as? String,
     !plistValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
     !plistValue.contains("$(")
  {
    return plistValue.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  fatalError("Missing required config value for \(key). Set it in environment or Info.plist build settings.")
}

private func validatedSupabaseURL() -> URL {
  let raw = requiredConfigValue(for: "SUPABASE_URL")
  guard let url = URL(string: raw),
        let scheme = url.scheme?.lowercased(),
        (scheme == "https" || scheme == "http"),
        let host = url.host,
        !host.isEmpty
  else {
    fatalError("Invalid SUPABASE_URL '\(raw)'. Expected format: https://your-project-ref.supabase.co")
  }
  return url
}

private func validatedAnonKey() -> String {
  let key = requiredConfigValue(for: "SUPABASE_ANON_KEY")
  guard !key.contains("REPLACE_WITH_NEW_ANON_KEY") else {
    fatalError("SUPABASE_ANON_KEY is still placeholder text.")
  }
  guard !key.contains("<") && !key.contains(">") else {
    fatalError("SUPABASE_ANON_KEY includes angle brackets. Paste only the raw key value.")
  }
  return key
}

let supabaseURLValue = validatedSupabaseURL()
let supabaseAnonKeyValue = validatedAnonKey()
let supabaseURLString = supabaseURLValue.absoluteString

let supabase = SupabaseClient(
  supabaseURL: supabaseURLValue,
  supabaseKey: supabaseAnonKeyValue
)

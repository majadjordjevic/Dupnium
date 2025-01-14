//
//  Dupnium.swift
//  Dupnium
//
//  Created by Bas van Kuijck on 18-08-16.
//  Copyright © 2016 E-sites. All rights reserved.
//

import Foundation
import UIKit

open class Dupnium {
    enum Constants {
        fileprivate static let userDefaultsLocaleKey = "userDefaultsLocaleKey"
        static let localeChangedNotificationName = Notification.Name("_dupniumLocaleChanged")
    }
    
    public static let shared = Dupnium()

    open var debugModus = false
    
    open var fallbackLocale: Locale = Locale.current {
        didSet {
            if _getBundle(locale: fallbackLocale) == nil {
                fatalError("[Localization] Cannot find '\(language(for: fallbackLocale) ?? "").lproj/Localizable.strings' for `fallBackLocale`")
            }
            self._update()
        }
    }
    
    open var locale: Locale = Locale.current {
        didSet {
            self._update()
            NotificationCenter.default.post(name: Constants.localeChangedNotificationName, object: self, userInfo: [ "locale": locale ])
        }
    }
    
    public init() {
        defer {
            #if DEBUG
                self.debugModus = true
            #endif
            
            if let identifier = UserDefaults.standard.string(forKey: Constants.userDefaultsLocaleKey) {
                self.locale = Locale(identifier:  identifier)
            }
            self._update()
        }
    }
    
    fileprivate var localeBundle: Bundle = Bundle.main
    open var bundle: Bundle = Bundle.main {
        didSet {
            _update()
        }
    }

    private func language(for locale: Locale) -> String? {
        return locale.identifier.replacingOccurrences(of: "-", with: "_").components(separatedBy: "_").first
    }

    open var language: String {
        return language(for: locale) ?? "en"
    }
    
    private func _getBundle(locale: Locale) -> Bundle? {
        if let fullPath = bundle.path(forResource: locale.identifier.replacingOccurrences(of: "_", with: "-"), ofType: "lproj"),
           FileManager.default.fileExists(atPath: fullPath) {
            return Bundle(path: fullPath)
        }
        
        if let language = language(for: locale),
           let path = bundle.path(forResource: language, ofType: "lproj") {
            return Bundle(path: path)
        }
        
        return nil
    }
    
    fileprivate func _update() {
        guard let bundle = _getBundle(locale: locale) else {
            if locale != fallbackLocale {
                let l = language
                locale = fallbackLocale
                if debugModus {
                    NSLog("[Dubnium] Cannot find '\(l).lproj/Localizable.strings', using `\(language).lproj/Localizable.strings` instead")
                }
            }
            return
        }
        self.localeBundle = bundle
        
        UserDefaults.standard.set(locale.identifier, forKey: Constants.userDefaultsLocaleKey)
    }
    
    open subscript(key: String) -> String {
        return string(key)
    }
    
    open func string(_ key: String) -> String {
        let model = UIDevice.current.model
        if model == "iPad" || model == "iPad Simulator" {
            let ipadKey = key + "~ipad"
            if let ipadStr = getString(ipadKey), ipadStr != ipadKey {
                return ipadStr
            }
        }
        
        guard let str = getString(key) else {
            let sk = key.replacingOccurrences(of: "%", with: "%%")
            if debugModus {
                NSLog("[Dubnium] Cannot find localization for '\(sk)' in '\(language).lproj/Localizable.strings'")
            }
            return key
        }
        return str
    }

    @objc
    open func getString(_ key: String, locale: Locale? = nil) -> String? {
        // - If key is nil and value is nil, returns an empty string.
        // - If key is nil and value is non-nil, returns value.
        // - If key is not found and value is nil or an empty string, returns key.
        // - If key is not found and value is non-nil and not empty, return value.
        var bundle = localeBundle
        if let locale = locale, let aBundle = _getBundle(locale: locale) ?? _getBundle(locale: fallbackLocale) {
            bundle = aBundle
        }
        let notFoundString = "__NOTFOUND:\(key)"
        let returnValue = bundle.localizedString(forKey: key, value: notFoundString, table: nil)
        if returnValue == notFoundString {
            return nil
        }
        return returnValue
    }

    open subscript(key: String, value: Int) -> String {
        return plural(key, value: value)
    }

    open subscript(key: String, value: Double) -> String {
        return plural(key, value: value)
    }

    open func plural(_ key: String, value: Double) -> String {
        let form = PluralForm.getForm(self.language, n: value)
        let keyVariant = String(format: "%@##{%@}", key, form.rawValue)
        let format = self[keyVariant]
        return String(format: format, value)
    }

    open func plural(_ key: String, value: Int) -> String {
        let form = PluralForm.getForm(self.language, n: Double(value))
        let keyVariant = String(format: "%@##{%@}", key, form.rawValue)
        let format = self[keyVariant]
        return String(format: format, value)
    }

    
    open func data(fromResourceName name: String, withExtension ext: String) -> Data? {
        guard let path = localeBundle.path(forResource: name, ofType: ext) else {
            return nil
        }
        return try? Data(contentsOf: URL(fileURLWithPath: path))
    }
    
    open func image(named name: String, withExtension ext: String = "png") -> UIImage? {
        guard let path = localeBundle.path(forResource: name, ofType: ext) else {
            return nil
        }
        return UIImage(contentsOfFile: path)
    }
}

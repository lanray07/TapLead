import XCTest

final class LocalizationUITests: XCTestCase {
    func testTranslatedNavigationEditorAndPaywallInEveryLanguage() {
        // Independent expectations catch missing bundled resources and String/LocalizedStringKey mistakes.
        let locales: [(String, String, String, String, String, String, String, String)] = [
            ("en", "en_GB", "Today", "My card", "Connections", "Settings", "Edit card", "Cancel"),
            ("es", "es_ES", "Hoy", "Mi tarjeta", "Contactos", "Configuración", "Editar tarjeta", "Cancelar"),
            ("fr", "fr_FR", "Aujourd'hui", "Ma carte", "Contacts", "Paramètres", "Modifier la carte", "Annuler"),
            ("de", "de_DE", "Heute", "Meine Karte", "Kontakte", "Einstellungen", "Karte bearbeiten", "Abbrechen"),
            ("it", "it_IT", "Oggi", "Il mio biglietto", "Contatti", "Impostazioni", "Modifica scheda", "Annulla"),
            ("pt", "pt_BR", "Hoje", "Meu cartão", "Contatos", "Configurações", "Editar cartão", "Cancelar"),
            ("nl", "nl_NL", "Vandaag", "Mijn kaart", "Contacten", "Instellingen", "Kaart bewerken", "Annuleren"),
            ("ja", "ja_JP", "今日", "自分のカード", "人脈", "設定", "カードを編集", "キャンセル"),
            ("ko", "ko_KR", "오늘", "내 카드", "인맥", "설정", "카드 편집", "취소"),
            ("zh-Hans", "zh_CN", "今天", "我的名片", "联系人", "设置", "编辑名片", "取消")
        ]
        for (language, region, today, card, contacts, settings, edit, cancel) in locales {
            let app = XCUIApplication()
            app.launchArguments = ["--demo", "-AppleLanguages", "(\(language))", "-AppleLocale", region]
            app.launch()
            XCTAssertTrue(app.tabBars.buttons[today].waitForExistence(timeout: 10), language + app.debugDescription)
            capture(app, language, "today")
            app.tabBars.buttons[card].tap()
            let editor = app.buttons[edit]
            XCTAssertTrue(editor.waitForExistence(timeout: 5), language + app.debugDescription)
            for _ in 0..<3 { if editor.isHittable { break }; app.swipeUp() }
            XCTAssertTrue(editor.isHittable, language + app.debugDescription)
            capture(app, language, "card")
            editor.tap()
            XCTAssertTrue(app.buttons[cancel].waitForExistence(timeout: 5), language + app.debugDescription)
            capture(app, language, "editor")
            app.buttons[cancel].tap()
            app.tabBars.buttons[contacts].tap()
            XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: 5))
            capture(app, language, "contacts")
            app.tabBars.buttons[settings].tap()
            app.buttons["TapLead Pro"].tap()
            let close = ["en":"Close", "es":"Cerrar", "fr":"Fermer", "de":"Schließen", "it":"Chiudi", "pt":"Fechar", "nl":"Sluiten", "ja":"閉じる", "ko":"닫기", "zh-Hans":"关闭"][language]!
            XCTAssertTrue(app.buttons[close].waitForExistence(timeout: 5), language + app.debugDescription)
            capture(app, language, "pro")
            app.terminate()
        }
    }

    private func capture(_ app: XCUIApplication, _ language: String, _ screen: String) {
        let image = XCTAttachment(screenshot: app.screenshot())
        image.name = "TapLead-locale-\(language)-\(screen)"
        image.lifetime = .keepAlways
        add(image)
    }
}

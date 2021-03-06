package haxe.ui.backend;

import haxe.Timer;
import haxe.ui.core.Component;
import haxe.ui.backend.html5.HtmlUtils;
import haxe.ui.styles.Style;
import js.Browser;
import js.html.CSSStyleDeclaration;
import js.html.DivElement;
import js.html.Element;

class TextDisplayBase {
    public var element:Element;

    public var parentComponent:Component;

    public function new() {
        element = Browser.document.createDivElement();
        //element.style.display = "inline";
        element.style.position = "absolute";
        element.style.cursor = "inherit";
        multiline = false;
    }

    private var _text:String;
    public var text(get, set):String;
    private function get_text():String {
        return element.innerHTML;
    }
    private var _dirty:Bool = false;
    private function set_text(value:String):String {
        if (value == _text) {
            return value;
        }

        /*
        if (value == null || value.length == 0) {
            _text = value;
            _dirty = true;
            return value;
        }
        */

        var html:String = normalizeText(value);
        element.innerHTML = html;

        _dirty = true;
        _text = value;
        measureText();
        return value;
    }

    private var _left:Float = 0;
    public var left(get, set):Float;
    private function get_left():Float {
        return _left;
    }
    private function set_left(value:Float):Float {
        if (value == _left) {
            return value;
        }

        _left = value;
        updatePos();
        return value;
    }

    private var _top:Float = 0;
    public var top(get, set):Float;
    private function get_top():Float {
        return _top;
    }
    private function set_top(value:Float):Float {
        if (value == _top) {
            return value;
        }

        _top = value;
        updatePos();
        return value;
    }

    private var _width:Float = -1;
    public var width(get, set):Float;
    public function set_width(value:Float):Float {
        if (_width == value) {
            return value;
        }
        _width = value;
        updateSize();
        return value;
    }

    public function get_width():Float {
        return _width;
    }

    private var _height:Float = -1;
    public var height(get, set):Float;
    public function set_height(value:Float):Float {
        if (_height == value) {
            return value;
        }
        _height = value;
        updateSize();
        return value;
    }

    public function get_height():Float {
        return _height;
    }

    private var _textWidth:Float = 0;
    public var textWidth(get, null):Float;
    private function get_textWidth():Float {
        if (_text == null || _text.length == 0) {
            return 0;
        }
        if (_textWidth == 0) {
            _dirty = true;
            measureText();
        }
        return _textWidth;
    }

    private var _textHeight:Float = 0;
    public var textHeight(get, null):Float;
    private function get_textHeight():Float {
        if (_textHeight == 0) {
            _dirty = true;
            measureText();
        }
        return _textHeight;
    }

    public function applyStyle(style:Style) {
        if (style.color != null) {
            element.style.color = HtmlUtils.color(style.color);
        }
        if (style.fontName != null) {
            applyFontName(style.fontName);
        }
        if (style.fontSize != null) {
            element.style.fontSize = HtmlUtils.px(style.fontSize);
            _dirty = true;
            measureText();
        }
        if (style.fontBold != null) {
            element.style.fontWeight = style.fontBold == true ? "bold" : "normal";
            _dirty = true;
            measureText();
        }
        if (style.textAlign != null) {
            element.style.textAlign = style.textAlign;
        }
    }
    
    private static var ADDED_FONTS:Map<String, String> = new Map<String, String>();

    private var _rawFontName:String;
    private var _fontName:String;
    private function applyFontName(value:String) {
        if (_rawFontName == value) {
            measureText();
            return value;
        }
        _rawFontName = value;

        // TODO: probably a better way to do all this
        var customFont:Bool = false;
        if (value.indexOf(".") != -1) {
            customFont = true;
            var cssName = value.split("/").pop();
            var n = cssName.lastIndexOf(".");
            if (n != -1) {
                cssName = cssName.substring(0, n);
            }
            if (ADDED_FONTS.exists(value) == false) {
                var css = '@font-face { font-family: "${cssName}"; src: url("${value}"); }';
                var style = Browser.document.createElement("style");
                Browser.document.head.appendChild(style);
                style.innerHTML = css;
                ADDED_FONTS.set(value, cssName);
            }

            value = cssName;
        }

        if (_fontName == value) {
            measureText();
            return value;
        }
        _fontName = value;

        element.style.fontFamily = _fontName;
        _dirty = true;
        measureText();
        //parentComponent.invalidate();
        parentComponent.invalidateLayout();

        if (customFont == true) {
            if (_checkSizeTimer == null) {
                _originalSize = element.clientWidth;
                _checkSizeTimer = new Timer(10);
                _checkSizeTimer.run = checkSize;
            }
        }

        return value;
    }

    private var _checkSizeTimer:Timer;
    private var _checkSizeCounter:Int = 0;
    private var _originalSize:Float = 0;
    private function checkSize() {
        if (element.clientWidth != _originalSize) {
            _checkSizeCounter = 0;
            //parentComponent.invalidate();
            _checkSizeTimer.stop();
            _checkSizeTimer = null;
            return;
        }

        _checkSizeCounter++;
        if (_checkSizeCounter >= 50) {
            _checkSizeCounter = 0;
            //parentComponent.invalidate();
            _checkSizeTimer.stop();
            _checkSizeTimer = null;
            return;
        }

    }

    private var _multiline:Bool = true;
    public var multiline(get, set):Bool;
    private function get_multiline():Bool {
        return _multiline;
    }
    private function set_multiline(value:Bool):Bool {
        if (value == _multiline) {
            return value;
        }

        _multiline = value;
        return value;
    }

    private var _wordWrap:Bool = false;
    public var wordWrap(get, set):Bool;
    private function get_wordWrap():Bool {
        return _wordWrap;
    }
    private function set_wordWrap(value:Bool):Bool {
        if (value == _wordWrap) {
            return value;
        }

        _wordWrap = value;
        if (_wordWrap == true) {
            element.style.removeProperty("white-space");
        } else {
            element.style.whiteSpace = "nowrap";
        }
        measureText();

        return value;
    }

    //***********************************************************************************************************
    // Util functions
    //***********************************************************************************************************
    private function updatePos() {
        var style:CSSStyleDeclaration = element.style;
        style.left = HtmlUtils.px(_left - 1);
        style.top = HtmlUtils.px(_top - 1);
    }

    private function updateSize() {
        var style:CSSStyleDeclaration = element.style;
        if (width > 0) {
            style.width = HtmlUtils.px(width);
        }
        if (height > 0) {
            style.height = HtmlUtils.px(height);
        }
        _dirty = true;
        measureText();
    }

    private function measureText() {
        if (_dirty == false) {
            return;
        }

        var t:String = _text;
        if (t == null || t.length == 0) {
            t = "|";
        }

        var html:String = normalizeText(t);

        var div = createTempDiv(html);
        Browser.document.body.appendChild(div);

        _textWidth = div.clientWidth + 2;
        _textHeight = div.clientHeight;
        HtmlUtils.removeElement(div);
        _dirty = false;
    }

    private function createTempDiv(html:String):Element {
        var div = Browser.document.createElement("div");
        div.id = "temp";
        div.style.position = "absolute";
        div.style.top = "-99999px"; // position off-screen!
        div.style.left = "-99999px"; // position off-screen!
        div.style.visibility = "hidden";
        //div.style.display = "none";
        div.style.fontFamily = element.style.fontFamily;
        div.style.fontSize = element.style.fontSize;
        div.style.fontWeight = element.style.fontWeight;
        div.innerHTML = html;
        if (width > 0) {
            div.style.width = '${HtmlUtils.px(width)}';
        }
        return div;
    }

    private function normalizeText(text:String):String {
        var html:String = HtmlUtils.escape(text);
        html = StringTools.replace(html, "\\n", "\n");
        html = StringTools.replace(html, "\r\n", "<br/>");
        html = StringTools.replace(html, "\r", "<br/>");
        html = StringTools.replace(html, "\n", "<br/>");
        return html;
    }
}

## Acción que se mantiene pulsada (forzar, encargo, robar ropa...).
class_name Hold
extends RefCounted

var type := ""
var ref = null
var t := 0.0
var dur := 1.0
var auto := false   # sigue aunque sueltes la tecla (se cancela al moverte)

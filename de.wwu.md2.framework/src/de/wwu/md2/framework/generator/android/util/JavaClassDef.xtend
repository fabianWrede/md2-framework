package de.wwu.md2.framework.generator.android.util

class JavaClassDef {
	public String simpleName
	public String basePackage
	public String subPackage
	public CharSequence contents
	
	def getName() {
		fullPackage + "." + simpleName
	}
	
	def getFileName() {
		basePackage + "/src/" + name.replace('.', '/') + ".java"
	}
	
	def void setSimpleName(String value) {
		simpleName = value.toFirstUpper
	}
	
	def getFullPackage() {
		basePackage + "." + subPackage
	}
}
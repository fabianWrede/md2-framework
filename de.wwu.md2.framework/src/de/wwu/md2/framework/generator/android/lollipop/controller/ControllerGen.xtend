package de.wwu.md2.framework.generator.android.lollipop.controller

import de.wwu.md2.framework.generator.android.lollipop.Settings
import de.wwu.md2.framework.generator.android.lollipop.util.MD2AndroidLollipopUtil
import de.wwu.md2.framework.mD2.App
import de.wwu.md2.framework.mD2.ContentProvider
import de.wwu.md2.framework.mD2.Entity
import de.wwu.md2.framework.mD2.ReferencedModelType
import de.wwu.md2.framework.mD2.SimpleType

class ControllerGen {
	def static generateController(String mainPackage, App app, Iterable<Entity> entities, Iterable<ContentProvider> contentProviders)'''
		// generated in de.wwu.md2.framework.generator.android.lollipop.controller.Md2Controller.generateController()
		package «mainPackage».md2.controller;
		
		import android.app.Activity;
		
		import «mainPackage».«app.name.toFirstUpper»;
		
		«FOR e:entities»
			import «mainPackage».md2.model.«e.name.toFirstUpper»;
		«ENDFOR»
		
		«FOR cp:contentProviders»
			import «mainPackage».md2.model.contentProvider.«cp.name.toFirstUpper»;
		«ENDFOR»
		
		import java.util.ArrayList;
		import java.util.HashSet;
		
		«MD2AndroidLollipopUtil.generateImportAllActions»
		«MD2AndroidLollipopUtil.generateImportAllTypes»
		«MD2AndroidLollipopUtil.generateImportAllExceptions»
		«MD2AndroidLollipopUtil.generateImportAllEventHandler»
		«MD2AndroidLollipopUtil.generateImportAllCustomCodeTasks»
		
		import «Settings.MD2LIBRARY_PACKAGE»controller.implementation.AbstractMd2Controller;
		import «Settings.MD2LIBRARY_PACKAGE»model.contentProvider.implementation.Md2ContentProviderRegistry;
		import «Settings.MD2LIBRARY_PACKAGE»model.contentProvider.interfaces.Md2ContentProvider;
		import «Settings.MD2LIBRARY_PACKAGE»model.dataStore.implementation.Md2LocalStoreFactory;
		import «Settings.MD2LIBRARY_PACKAGE»model.dataStore.interfaces.Md2SQLiteHelper;
		import «Settings.MD2LIBRARY_PACKAGE»model.dataStore.implementation.Md2SQLiteDataStore;
		import «Settings.MD2LIBRARY_PACKAGE»view.management.implementation.Md2ViewManager;
		
		public class Controller extends AbstractMd2Controller {
		
			protected ArrayList<Md2CustomCodeTask> pendingTasks;
		
		    private static Controller instance;
		
		    private Controller() {
		        pendingTasks = new ArrayList<Md2CustomCodeTask>();
		    }
		
		    public static synchronized Controller getInstance() {
		        if (Controller.instance == null) {
		            Controller.instance = new Controller();
		        }
		        return Controller.instance;
		    }
		
		    @Override
		    public void run() {
		        this.registerContentProviders();
		    }

		    public void registerContentProviders() {
		        Md2ContentProviderRegistry cpr = Md2ContentProviderRegistry.getInstance();
		        Md2LocalStoreFactory lsf = new Md2LocalStoreFactory(this.instance, "«mainPackage».md2.model.dataStore.LocalDataStoreFactory");
		        
		        «FOR cp: contentProviders»
		        	«var typeName = getTypeName(cp)»
		        	
		        	Md2ContentProvider «cp.name.toFirstLower» = new «cp.name.toFirstUpper»(new «MD2AndroidLollipopUtil.getTypeNameForContentProvider(cp)»(), (Md2SQLiteDataStore) lsf.getDataStore("«typeName»"));
		        	cpr.add("«cp.name»", «cp.name.toFirstLower»);
		        «ENDFOR»
		    }
		
		    @Override
		    public Md2SQLiteHelper getMd2SQLiteHelper() {
		        return «app.name.toFirstUpper».getMd2SQLiteHelper();
		    }
		}
	'''
	
	private static def getTypeName(ContentProvider cp){
		var type = cp.type
		switch type{ 
		    ReferencedModelType : type.entity.getName
		    SimpleType : type.type.getName()
		}
	}
}
package de.wwu.md2.framework.generator.preprocessor

import com.google.common.collect.Lists
import de.wwu.md2.framework.generator.util.MD2GeneratorUtil
import de.wwu.md2.framework.mD2.Attribute
import de.wwu.md2.framework.mD2.AutoGeneratedContentElement
import de.wwu.md2.framework.mD2.BooleanType
import de.wwu.md2.framework.mD2.ContentContainer
import de.wwu.md2.framework.mD2.ContentElement
import de.wwu.md2.framework.mD2.ContentProviderPathDefinition
import de.wwu.md2.framework.mD2.Controller
import de.wwu.md2.framework.mD2.CustomAction
import de.wwu.md2.framework.mD2.DateTimeType
import de.wwu.md2.framework.mD2.DateType
import de.wwu.md2.framework.mD2.Entity
import de.wwu.md2.framework.mD2.EntityPathDefinition
import de.wwu.md2.framework.mD2.Enum
import de.wwu.md2.framework.mD2.EnumType
import de.wwu.md2.framework.mD2.FloatType
import de.wwu.md2.framework.mD2.FlowDirection
import de.wwu.md2.framework.mD2.FlowLayoutPaneFlowDirectionParam
import de.wwu.md2.framework.mD2.InputElement
import de.wwu.md2.framework.mD2.IntegerType
import de.wwu.md2.framework.mD2.MD2Factory
import de.wwu.md2.framework.mD2.ModelElement
import de.wwu.md2.framework.mD2.OptionInput
import de.wwu.md2.framework.mD2.PathTail
import de.wwu.md2.framework.mD2.ReferencedModelType
import de.wwu.md2.framework.mD2.ReferencedType
import de.wwu.md2.framework.mD2.SimpleDataType
import de.wwu.md2.framework.mD2.SimpleType
import de.wwu.md2.framework.mD2.StringType
import de.wwu.md2.framework.mD2.TimeType
import de.wwu.md2.framework.mD2.ViewElementDef
import de.wwu.md2.framework.mD2.ViewGUIElement
import java.util.Collection
import java.util.List
import org.eclipse.emf.ecore.resource.ResourceSet

import static de.wwu.md2.framework.generator.preprocessor.util.Util.*

import static extension de.wwu.md2.framework.generator.util.MD2GeneratorUtil.*

class ProcessAutoGenerator {
	
	public static String autoGenerationActionName = "__autoGenerationAction"
	public static int autoGenerationCounter = 0
	
	/**
	 * If there are any AutoGenerator elements in the model, create CustomAction named <i>__autoGenerationAction</i>
	 * for mappings and validators and register it in the __startUpAction.
	 * 
	 * <p>
	 *   DEPENDENCIES: None
	 * </p>
	 * <ul>
	 *   <li>
	 *     <i>createStartUpActionAndRegisterAsOnInitializedEvent</i> - The AutoGenerationAction is added to the __startUpAction.
	 *   </li>
	 * </ul>
	 */
	def static void createAutoGenerationAction(MD2Factory factory, ResourceSet workingInput, Iterable<AutoGeneratedContentElement> autoGenerators) {
		
		// avoid creation of autogeneratedAction if no
		// AutoGeneratedContentElement exist in the model
		if(autoGenerators.empty) {
			return
		}
		
		if (getAutoGenAction(workingInput) == null) {
			val ctrl = workingInput.resources.map[ r |
				r.allContents.toIterable.filter(typeof(Controller))
			].flatten.last
			
			if (ctrl != null) {
				
				val startupAction = workingInput.resources.map[ r |
					r.allContents.toIterable.filter(typeof(CustomAction))
						.filter( action | action.name.equals(ProcessController::startupActionName))
				].flatten.last
				
				// create __autoGenerationAction
				val autoGenAction = factory.createCustomAction();
				autoGenAction.setName(autoGenerationActionName)
				ctrl.controllerElements.add(autoGenAction)
				
				// add __autoGenerationAction action to __startupAction
				val autoGenCallTask = factory.createCallTask
				val autoGenActionReference = factory.createActionReference
				autoGenActionReference.setActionRef(autoGenAction)
				autoGenCallTask.setAction(autoGenActionReference)
				startupAction.codeFragments.add(0, autoGenCallTask);
				
			}
		}
	}
	
	/**
	 * Create view elements for AutoGeneratorPane and add MappingTasks
	 */
	def static void createViewElementsForAutoGeneratorAction(MD2Factory factory, ResourceSet workingInput, Iterable<AutoGeneratedContentElement> autoGenerators) {
		
		// autoGenerators to remain as view, because new (superfluous) generators might be created later when resolving
		// view references (generators are only deleted at the end) toList only for iteration without concurrent modification
		autoGenerators.toList.forEach [ autoGenerator | 
			
			// Search for parent container => do not hard code to reflect potential changes in the grammar
			// Assumed structure at the moment: ContainerElement -> ViewElementType -> AutoGeneratedContentElement
			var parentContainer = autoGenerator.eContainer
			while (!(parentContainer instanceof ContentContainer)) {
				parentContainer = parentContainer.eContainer
			}
			
			val elements = (parentContainer as ContentContainer).elements
			
			// TODO -- refactor/comment to make it better understandable
			val pos = elements.indexOf(autoGenerator.eContainer)
			autoGenerator.contentProvider.forEach [ contentProviderReference |
				val contentProvider = contentProviderReference.contentProvider
				val ContentProviderPathDefinition pathDefinition = factory.createContentProviderPathDefinition()
				pathDefinition.setContentProviderRef(contentProvider)
				switch (contentProvider.type) {
					ReferencedModelType: {
						val modelElement = (contentProvider.type as ReferencedModelType).entity
						val Collection<EntityPathDefinition> filteredAttributes = newHashSet()
						if (autoGenerator.filteredAttributes.size > 0) {
							if (autoGenerator.exclude) {
								filteredAttributes.addAll(autoGenerator.filteredAttributes) 
							} else {
								val entityPathDefinition = factory.createEntityPathDefinition()
								entityPathDefinition.entityRef = modelElement as Entity
								filteredAttributes.addAll(entityToPathDefinition(factory, entityPathDefinition, modelElement as Entity))
								val iter = filteredAttributes.iterator
								while (iter.hasNext) {
									val obj = iter.next
									var continue = false
									for (includePathDefinition : autoGenerator.filteredAttributes) {
										if (!continue && MD2GeneratorUtil::equals(obj, includePathDefinition)) {
											iter.remove
											continue = true
										} 
									}
								} 
							}
						}
						val Collection<ViewElementDef> viewDefs = modelToView(factory, workingInput, modelElement, pathDefinition, filteredAttributes).toList						
						elements.addAll(pos, viewDefs);
						// do not remove autoGenerator here, because its containment hierarchy is still needed for resolving GUI references
						// autoGenerators will be removed at the end of preprocessing
						
//						if (it.type.many) {
//							pathDefinition.tail = factory.createPathTail()
//							pathDefinition.tail.attributeRef = {
//								val AttributeType attr = (modelElement as Entity).attributes.filter([!filteredAttributes.map([it.referencedAttribute]).toList.contains(it)]).map([it.type]).findFirst([!it.eAllContents.filter(typeof(AttrIdentifier)).empty])
//								if (attr != null) attr.eContainer as Attribute else (modelElement as Entity).attributes.head
//							}
//							val viewElementDef = factory.createViewElementDef()					
//							viewElementDef.value = factory.createEntitySelector()
//							viewElementDef.value.name = modelElement.name.toFirstLower + "EntitySelector"
//							(viewElementDef.value as EntitySelector).textProposition = pathDefinition
//							elements.add(pos, viewElementDef);
//						}					
					}
					SimpleType: {
						val simpleDataType = (contentProvider.type as SimpleType).type
						var ViewElementDef viewDef = modelToView2(factory, workingInput, simpleDataType, pathDefinition)
						// TODO: Generate EntitySelector
						//if (it.type.many) viewDef = wrapIntoMultiPane(factory, viewDef, simpleDataType.name + "MultiPane")
						elements.add(pos, viewDef); // do not remove autoGenerator here
					}
				}
			]
		]
	}
	
	
	
	////////////////////////////////////////////////////////////////////////////
	/// Helper methods
	////////////////////////////////////////////////////////////////////////////
	
	def static CustomAction getAutoGenAction(ResourceSet input) {
		input.resources.map[r |
			r.allContents.toIterable.filter(typeof(CustomAction)).filter(action | action.name == autoGenerationActionName)
		].flatten.last
	}
	
	def private static Collection<EntityPathDefinition> entityToPathDefinition(MD2Factory factory, EntityPathDefinition pathDefinition, Entity element) { 
		val Collection<EntityPathDefinition> entityPathes = newHashSet()
		element.attributes.forEach [
			val iterPathDefinition = copyElement(pathDefinition) as EntityPathDefinition
			if (iterPathDefinition.lastPathTail == null) {
				iterPathDefinition.tail = factory.createPathTail() 
			} else {
				iterPathDefinition.lastPathTail.tail = factory.createPathTail()
			}
			iterPathDefinition.lastPathTail.setAttributeRef(it)
			entityPathes.add(iterPathDefinition)
			if (it instanceof ReferencedType && (it as ReferencedType).entity instanceof Entity) {
				entityPathes.addAll(entityToPathDefinition(factory, iterPathDefinition, (it as ReferencedType).entity as Entity))
			}
		]
		entityPathes
	}
	
	def private static Iterable<ViewElementDef> modelToView(
		MD2Factory factory, ResourceSet input, ModelElement m, ContentProviderPathDefinition pathDefinition,
		Collection<EntityPathDefinition> filteredAttributes
	) {
		modelToView(factory, input, m, pathDefinition, filteredAttributes, null)
	}
	
	def private static Iterable<ViewElementDef> modelToView(
		MD2Factory factory, ResourceSet input, ModelElement m, ContentProviderPathDefinition pathDefinition,
		Collection<EntityPathDefinition> filteredAttributes, String labelPrefix
	) {
		val List<ViewElementDef> viewElements = Lists::newArrayList
		if (m instanceof Entity) {
			(m as Entity).attributes.forEach [ a |
				val viewElementDef = factory.createViewElementDef()
				
				// New PathDefinition for every attribute
				val pathDefinitionIter = copyElement(pathDefinition) as ContentProviderPathDefinition
				val PathTail pathTail = factory.createPathTail()
				pathTail.setAttributeRef(a)
				if (pathDefinitionIter.getTail == null) pathDefinitionIter.setTail(pathTail)
				else getLastPathTail(pathDefinitionIter).setTail(pathTail)
				
				var boolean skip = false
				for (filterPathDefinition : filteredAttributes) {
					if (MD2GeneratorUtil::equals(pathDefinitionIter, filterPathDefinition)) skip = true
				}
				if (!skip) {
//					if (a.type.many) {
//						viewElementDef.value = factory.createEntitySelector()
//						viewElementDef.value.name = a.name + "EntitySelector"
//						(viewElementDef.value as EntitySelector).textProposition = pathDefinitionIter
//					} else {
						switch (a.type) {
							ReferencedType: {
								if ((a.type as ReferencedType).entity instanceof Entity) {
									val flowLayoutPane = factory.createFlowLayoutPane()
									flowLayoutPane.name = a.name + "FlowLayoutPane"
									// Recursive modelToView for referenced entities
									for (childElem : modelToView(factory, input, (a.type as ReferencedType).entity, copyElement(pathDefinitionIter) as ContentProviderPathDefinition, filteredAttributes, a.labelText + " - ")) {
										flowLayoutPane.elements.add(childElem as ViewElementDef)
									}
									flowLayoutPane.params.add(factory.createFlowLayoutPaneFlowDirectionParam)
									(flowLayoutPane.params.get(0) as FlowLayoutPaneFlowDirectionParam).flowDirection = FlowDirection::VERTICAL
									viewElementDef.value = flowLayoutPane
								} else if ((a.type as ReferencedType).entity instanceof Enum) {
									viewElementDef.value = factory.createOptionInput().applyLabelAndTooltip(a, labelPrefix)
									viewElementDef.value.name = "__" + a.name + "OptionInput" + "_" + autoGenerationCounter.toString;
									(viewElementDef.value as OptionInput).enumReference = ((a.type as ReferencedType).entity as Enum)
								}
							}
							BooleanType: {
								viewElementDef.value = factory.createBooleanInput().applyLabelAndTooltip(a, labelPrefix)
								viewElementDef.value.name = "__" + a.name + "BooleanInput" + "_" + autoGenerationCounter.toString
							}
							IntegerType: {
								viewElementDef.value = factory.createIntegerInput().applyLabelAndTooltip(a, labelPrefix)
								viewElementDef.value.name = "__" + a.name + "IntegerInput" + "_" + autoGenerationCounter.toString
							}
							FloatType: {
								viewElementDef.value = factory.createNumberInput().applyLabelAndTooltip(a, labelPrefix)
								viewElementDef.value.name = "__" + a.name + "NumberInput" + "_" + autoGenerationCounter.toString
							}
							StringType: {
								viewElementDef.value = factory.createTextInput().applyLabelAndTooltip(a, labelPrefix)
								viewElementDef.value.name = "__" + a.name + "TextInput" + "_" + autoGenerationCounter.toString
							}
							DateType: {
								viewElementDef.value = factory.createDateInput().applyLabelAndTooltip(a, labelPrefix)
								viewElementDef.value.name = "__" + a.name + "DateInput" + "_" + autoGenerationCounter.toString
							}
							TimeType: {
								viewElementDef.value = factory.createTimeInput().applyLabelAndTooltip(a, labelPrefix)
								viewElementDef.value.name = "__" + a.name + "TimeInput" + "_" + autoGenerationCounter.toString
							}
							DateTimeType: {
								viewElementDef.value = factory.createDateTimeInput().applyLabelAndTooltip(a, labelPrefix)
								viewElementDef.value.name = "__" + a.name + "DateTimeInput" + "_" + autoGenerationCounter.toString
							}
							EnumType: {
								System::err.println("[M2M] Oops: Encountered implicit enum " + a.name + ". Should be transformed already.")
							}
							default: {
								System::err.println("[M2M] Oops: Encountered unsupported Attribute type " + a.type.eClass.name + ".")
							}
						}
						addDataMapping(factory, input, viewElementDef.value, pathDefinitionIter)				
//					}
					viewElements.add(viewElementDef)							
				}
			]
		}
		autoGenerationCounter = autoGenerationCounter + 1
		viewElements
	}
	
	def private static ViewElementDef modelToView2(MD2Factory factory, ResourceSet input, SimpleDataType s, ContentProviderPathDefinition pathDefinition) {
		val viewElementDef = factory.createViewElementDef()
		switch (s) {
			case SimpleDataType::INTEGER: viewElementDef.value = factory.createIntegerInput()
			case SimpleDataType::FLOAT: viewElementDef.value = factory.createNumberInput()
			case SimpleDataType::STRING: viewElementDef.value = factory.createTextInput()
			case SimpleDataType::BOOLEAN: viewElementDef.value = factory.createBooleanInput()
			case SimpleDataType::DATE: viewElementDef.value = factory.createDateInput()
			case SimpleDataType::TIME: viewElementDef.value = factory.createTimeInput()
			case SimpleDataType::DATE_TIME: viewElementDef.value = factory.createDateTimeInput()
		}
		viewElementDef.value.name = "__" + pathDefinition.contentProviderRef.name + viewElementDef.value.eClass.name + "_" + autoGenerationCounter.toString
		addDataMapping(factory, input, viewElementDef.value, pathDefinition)
		autoGenerationCounter = autoGenerationCounter + 1
		viewElementDef
	}
	
	def private static addDataMapping(MD2Factory factory, ResourceSet input, ViewGUIElement guiElem, ContentProviderPathDefinition pathDefinition) {
		val autoGenAction = getAutoGenAction(input)
		if (autoGenAction == null) return null
		val mappingTask = factory.createMappingTask()
		mappingTask.referencedViewField = factory.createAbstractViewGUIElementRef()
		mappingTask.referencedViewField.ref = guiElem
		mappingTask.pathDefinition = pathDefinition as ContentProviderPathDefinition
		autoGenAction.codeFragments.add(mappingTask)
	}
	
	def private static ContentElement applyLabelAndTooltip(ContentElement contentElement, Attribute attr, String labelPrefix) {
		val labelText = (labelPrefix?:"") + attr.labelText
		switch (contentElement) {
			InputElement: {
				contentElement.labelText = labelText
				contentElement.tooltipText = attr.description
			}
		}
		contentElement
	}
	
	def private static String getLabelText(Attribute attr) {
		switch (attr.extendedName) {
			String: attr.extendedName
			default: attr.name.toFirstUpper.replaceAll("(.)([A-Z])","$1 $2")
		}
	}
	
}
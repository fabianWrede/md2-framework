package de.wwu.md2.framework.generator.util

import de.wwu.md2.framework.mD2.AlternativesPane
import de.wwu.md2.framework.mD2.Condition
import de.wwu.md2.framework.mD2.ContainerElement
import de.wwu.md2.framework.mD2.ContainerElementDef
import de.wwu.md2.framework.mD2.ContentProvider
import de.wwu.md2.framework.mD2.Controller
import de.wwu.md2.framework.mD2.CustomAction
import de.wwu.md2.framework.mD2.GotoViewAction
import de.wwu.md2.framework.mD2.MD2Model
import de.wwu.md2.framework.mD2.Main
import de.wwu.md2.framework.mD2.Model
import de.wwu.md2.framework.mD2.OnConditionEvent
import de.wwu.md2.framework.mD2.RemoteValidator
import de.wwu.md2.framework.mD2.TabbedAlternativesPane
import de.wwu.md2.framework.mD2.View
import de.wwu.md2.framework.mD2.Workflow
import java.util.Collection
import java.util.List
import java.util.Map
import java.util.Set
import org.eclipse.emf.ecore.resource.ResourceSet

import static de.wwu.md2.framework.generator.util.MD2GeneratorUtil.*

/**
 * Singleton DataContainer to store data that are used throughout the
 * generation process.
 */
class DataContainer
{
	///////////////////////////////////////
	// Data Container
	///////////////////////////////////////
	
	public Collection<View> views
	
	public Collection<Controller> controllers
	
	public Collection<Model> models
	
	public Main main
	
	public Set<ContainerElement> viewContainers
	
	public Collection<ContentProvider> contentProviders
	
	public Collection<Workflow> workflows
	
	public Collection<CustomAction> customActions
	
	public Collection<OnConditionEvent> onConditionEvents
	
	public Collection<RemoteValidator> remoteValidators
	
	/*
	 * Contains a collection of all conditions, where the key represents the name of the condition
	 */
	public Map<String, Condition> conditions
	
	public TabbedAlternativesPane tabbedAlternativesPane
	
	public List<ContainerElement> tabbedViewContent
	
	public Set<ContainerElement> viewContainersInAnyAlternativesPane
	
	public Set<ContainerElement> viewContainersNotInAnyAlternativesPane
	
	
	/**
	 * Initializes the lists offered by the data container
	 */
	new(ResourceSet input) {
		intializeModelTypedLists(input)
		
		extractUniqueMain
		
		if(main == null) {
			return
		}
		
		extractElementsFromControllers
		
		postProcessViewCollection
	}
	
	/**
	 * Provide sets which are populated with all views, collections and models respectively.
	 */
	def private intializeModelTypedLists(ResourceSet input) {
		views = newHashSet()
		controllers = newHashSet()
		models = newHashSet()
		val Iterable<MD2Model> parts = input.resources.map(r | r.allContents.toIterable.filter(typeof(MD2Model))).flatten
		for(md2model : parts) {
			switch md2model.modelLayer {
				// Xtend resolves runtime argument type for modelLayer
				View : views.add(md2model.modelLayer as View)
				Model : models.add(md2model.modelLayer as Model)
				Controller : controllers.add(md2model.modelLayer as Controller)
			}
		}
	}
	
	/**
	 * Get the only main block of the app. This allows to easily access information such as the app name
	 * and app version without iterating over the object tree over and over again.
	 */
	def private extractUniqueMain() {
		val controllerContainingMain = controllers.findFirst(ctrl | ctrl.controllerElements.exists(ctrlElem | ctrlElem instanceof Main))
		if(controllerContainingMain != null) {
			main = controllerContainingMain.controllerElements.findFirst(ctrlElem | ctrlElem instanceof Main) as Main
		}
	}
	
	def private extractElementsFromControllers() {
		// Iterate over all controllers and collect relevant information:
		// About the views that have to be generated:
		//    Generate views => get start view and all called views in work flow steps and change view actions
		viewContainers = newHashSet
		customActions = newHashSet
		contentProviders = newHashSet
		workflows = newHashSet
		onConditionEvents = newHashSet
		conditions = newHashMap
		remoteValidators = newHashSet
		
		viewContainers.add(resolveContainerElement(main.startView));
		for (controller : controllers) {
			for (controllerElement : controller.controllerElements) {
				switch controllerElement {
					Workflow: {
						// Filter relevant views that may be root views
						controllerElement.workflowSteps.forEach [step |
							if(step.view != null) {
								viewContainers.add(resolveContainerElement(step.view))
							}
						]
						
						// Store work flow
						workflows.add(controllerElement)
						
						// Store conditions
						controllerElement.workflowSteps.forEach [step |
							if(step.forwardCondition != null) {
								conditions.put(step.name + "_ForwardCondition", step.forwardCondition)
							}
							if(step.backwardCondition != null) {
								conditions.put(step.name + "_BackwardCondition", step.backwardCondition)
							}
						]
					}
					
					CustomAction: {
						// Filter relevant views that may be root views
						controllerElement.eAllContents.toIterable.filter(typeof(GotoViewAction)).forEach [gotoViewAction |
							viewContainers.add(resolveContainerElement(gotoViewAction.view))
						]
						
						// Store custom actions to generate
						customActions.add(controllerElement)
					}
					
					ContentProvider: {
						contentProviders.add(controllerElement)
					}
					
					OnConditionEvent: {
						onConditionEvents.add(controllerElement)
						
						// Store condition
						if(controllerElement.condition != null) {
							conditions.put(controllerElement.name, controllerElement.condition)
						}
					}
					
					RemoteValidator: {
						remoteValidators.add(controllerElement)
					}
				}
			}
		}
	}
	
	def void postProcessViewCollection() {
		// Post-processing of view collection
		// => 1. get ordered list of all views that are in the tabbed pane
		tabbedViewContent = newArrayList
		views.forEach [view |
			val tabbedPane = view.viewElements.filter(typeof(TabbedAlternativesPane)).last
			if(tabbedPane != null) {
				// Save the TabbedAlternativesPane
				tabbedAlternativesPane = tabbedPane
				
				// Add all tabs to the respective list
				tabbedViewContent.addAll(tabbedPane.elements.filter(typeof(ContainerElementDef)).map(c | c.value))
				// Additionally add the tabs to the set of view containers (if they are already in there, they will not be added again since viewContainers is a set)
				viewContainers.addAll(tabbedPane.elements.filter(typeof(ContainerElementDef)).map(c | c.value))
			}
		]
		
		// => 2. extract all views that are direct children of an alternatives pane or tabbed alternatives pane from the set of views to generate
		viewContainersInAnyAlternativesPane = newHashSet
		viewContainersInAnyAlternativesPane.addAll(viewContainers.filter(c | c.eContainer.eContainer instanceof AlternativesPane))
		if(tabbedViewContent != null) {
			viewContainersInAnyAlternativesPane.addAll(tabbedViewContent)
		}
		
		// => 3. get set difference of (2.) and the set of views to generate
		viewContainersNotInAnyAlternativesPane = newHashSet
		viewContainersNotInAnyAlternativesPane.addAll(viewContainers)
		viewContainersNotInAnyAlternativesPane.removeAll(viewContainersInAnyAlternativesPane)
	}
}

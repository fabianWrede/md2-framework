package de.wwu.md2.framework.scoping;

import java.util.Collection;
import java.util.Set;

import org.eclipse.emf.common.util.TreeIterator;
import org.eclipse.emf.ecore.EClass;
import org.eclipse.emf.ecore.EObject;
import org.eclipse.emf.ecore.EReference;
import org.eclipse.emf.mwe2.language.scoping.QualifiedNameProvider;
import org.eclipse.xtext.naming.QualifiedName;
import org.eclipse.xtext.resource.IEObjectDescription;
import org.eclipse.xtext.scoping.IScope;
import org.eclipse.xtext.scoping.Scopes;
import org.eclipse.xtext.scoping.impl.AbstractDeclarativeScopeProvider;
import org.eclipse.xtext.scoping.impl.FilteringScope;

import com.google.common.base.Predicate;
import com.google.common.collect.Sets;
import com.google.inject.Inject;

import de.wwu.md2.framework.mD2.AbstractViewGUIElementRef;
import de.wwu.md2.framework.mD2.AttributeType;
import de.wwu.md2.framework.mD2.AutoGeneratedContentElement;
import de.wwu.md2.framework.mD2.ContainerElement;
import de.wwu.md2.framework.mD2.ContentElement;
import de.wwu.md2.framework.mD2.ContentProvider;
import de.wwu.md2.framework.mD2.ContentProviderPath;
import de.wwu.md2.framework.mD2.ContentProviderReference;
import de.wwu.md2.framework.mD2.DataType;
import de.wwu.md2.framework.mD2.Entity;
import de.wwu.md2.framework.mD2.EntityPath;
import de.wwu.md2.framework.mD2.FireEventEntry;
import de.wwu.md2.framework.mD2.MD2Package;
import de.wwu.md2.framework.mD2.ModelElement;
import de.wwu.md2.framework.mD2.PathTail;
import de.wwu.md2.framework.mD2.ReferencedModelType;
import de.wwu.md2.framework.mD2.ReferencedType;
import de.wwu.md2.framework.mD2.ViewElementType;
import de.wwu.md2.framework.mD2.ViewGUIElementReference;
import de.wwu.md2.framework.mD2.WorkflowElementEntry;
import de.wwu.md2.framework.mD2.WorkflowEvent;
import de.wwu.md2.framework.mD2.impl.FireEventEntryImpl;
import de.wwu.md2.framework.util.GetFiredEventsHelper;

/**
 * This class contains custom scoping description.
 * 
 * see : http://www.eclipse.org/Xtext/documentation/latest/xtext.html#scoping
 * on how and when to use it 
 *
 */
public class MD2ScopeProvider extends AbstractDeclarativeScopeProvider {
	
	@Inject
	private QualifiedNameProvider qualifiedNameProvider;
	
	@Inject
	private GetFiredEventsHelper helper;
	
	public static Collection<EClass> validContainerForAbstractViews = Sets.newHashSet(MD2Package.eINSTANCE.getMain(), MD2Package.eINSTANCE.getProcessChainStep(), MD2Package.eINSTANCE.getSimpleAction());
	

	IScope scope_FireEventEntry_event(FireEventEntry fireEventEntry, EReference eventRef) {
		WorkflowElementEntry wfe = (WorkflowElementEntry)(fireEventEntry.eContainer());
		
		// Get set of all Workflow Events fired within the Workflow Element
		Set<WorkflowEvent> firedEvents = helper.getFiredEvents(wfe.getWorkflowElement());
		
		// Remove those that are already handled in other FireEventEntries
		for (FireEventEntry otherFireEventEntry : wfe.getFiredEvents()) {
			// Really only consider others
			if (otherFireEventEntry == fireEventEntry) {
				continue;
			}
			
			// remove Entry:
			// requires access to implementation, because getEvent() causes
			// exceptions with cyclic references when trying to resolve the Workflow Event
			firedEvents.remove(
					((FireEventEntryImpl)otherFireEventEntry).basicGetEvent()
					);
		}
		
		return Scopes.scopeFor(firedEvents);
	}
	

	// Scoping for nested attributes
	IScope scope_PathTail_attributeRef(PathTail pathTail, EReference attributeRef) {
		Set<EObject> resultSet = Sets.newHashSet();
		EObject parent = pathTail.eContainer();
		if (parent instanceof PathTail) {
			AttributeType aType = ((PathTail) parent).getAttributeRef().getType();
			if (aType instanceof ReferencedType) {
				ModelElement modelElement = ((ReferencedType) aType).getElement();
				if (modelElement instanceof Entity) {
					resultSet.addAll(((Entity) modelElement).getAttributes());
				}
			}
					
		} else if (parent instanceof ContentProviderPath) {
			DataType dType = ((ContentProviderPath) parent).getContentProviderRef().getType();
			if (dType instanceof ReferencedModelType) {
				ModelElement modelElement = ((ReferencedModelType) dType).getEntity();
				if (modelElement instanceof Entity) {
					resultSet.addAll(((Entity) modelElement).getAttributes());
				}
			}
		} else if (parent instanceof EntityPath) {
			resultSet.addAll(((EntityPath) parent).getEntityRef().getAttributes());		
		}
		
		return Scopes.scopeFor(resultSet);
	}
	
	// Scoping for entities that are proxies for auto-generated view elements
	IScope scope_EntityPathDefinition_entityRef(final AbstractViewGUIElementRef context, EReference entityRef) {
		Set<EObject> resultSet = Sets.newHashSet();
		if (context.getRef() instanceof AutoGeneratedContentElement && !isRestrictedToContainer(context)) {
			for (ContentProviderReference ref : ((AutoGeneratedContentElement) context.getRef()).getContentProvider()) {
				ContentProvider cp = ref.getContentProvider();
				if (cp.getType() instanceof ReferencedModelType) {
					ModelElement m = ((ReferencedModelType) cp.getType()).getEntity();
					if (m instanceof Entity) {
						resultSet.add(m);
					}
				}
			}
		}
		return Scopes.scopeFor(resultSet);
	}
	
	// Scoping for referenced (to be copied) view elements
	IScope scope_AbstractViewGUIElementRef_ref(final EObject context, EReference ref) {
		IScope scope = delegateGetScope(context, ref);
		return new FilteringScope(scope, new Predicate<IEObjectDescription>() {
			@Override
			public boolean apply(IEObjectDescription input) {
				return isValidViewElement(context, input.getEObjectOrProxy());
			}
		});
	}	
	
	// Scoping for referenced (to be copied) view elements - 2. level
	IScope scope_AbstractViewGUIElementRef_ref(final AbstractViewGUIElementRef context, EReference ref) {
		if (context.eContainer() instanceof AbstractViewGUIElementRef) {
			// Obtain the type of the parent element
			AbstractViewGUIElementRef parent = (AbstractViewGUIElementRef) context.eContainer();
			if (isContentElement(parent)) {
				return IScope.NULLSCOPE;
			} else {
				final ContainerElement container;
				// Get the reference to the parent container
				if (parent.getRef() instanceof ViewGUIElementReference) {
					container = (ContainerElement) ((ViewGUIElementReference) parent.getRef()).getValue();
				} else {
					container = (ContainerElement) parent.getRef();	
				}
				// May be null in case of linking errors - quit gracefully to avoid NullPointer below
				if(container == null)
					return IScope.NULLSCOPE;
				IScope scope = delegateGetScope(context, ref);
				return new FilteringScope(scope, new Predicate<IEObjectDescription>() {
					@Override
					public boolean apply(IEObjectDescription input) {
						if (isValidViewElement(context, input.getEObjectOrProxy())) {
								TreeIterator<EObject> iter = container.eAllContents();
								while(iter.hasNext()) {
									EObject obj = iter.next();
									QualifiedName qualifiedName = qualifiedNameProvider.getFullyQualifiedName(obj);
									if (qualifiedName != null && qualifiedName.equals(input.getQualifiedName())) return true;									
								}
						}
						return false;
					}
				});
			}
		}
		return delegateGetScope(context, ref);
	}
	
//	// Scoping for referenced (to be copied) view elements in Workflows conditions
//	IScope scope_AbstractViewGUIElementRef_ref(final GuiElementStateExpression context, EReference ref) {
//		EObject parent = context;
//		while (parent.eContainer() != null) {
//			 parent = parent.eContainer();
//			 if (parent instanceof WorkflowStep) break;
//		}
//		IScope scope = delegateGetScope(context, ref);
//		if (parent == null) return scope;
//		final WorkflowStep step = (WorkflowStep) parent; 
//		return new FilteringScope(scope, new Predicate<IEObjectDescription>() {
//			@Override
//			public boolean apply(IEObjectDescription input) {
//				return (EcoreUtil.equals(step.getView().getRef(), input.getEObjectOrProxy()));
//			}
//		});
//	}	
	
	private static boolean isContentElement(AbstractViewGUIElementRef abtractRef) {
		ViewElementType objInQuestion = abtractRef.getRef();
		if (abtractRef.getRef() instanceof ViewGUIElementReference) {
			objInQuestion = ((ViewGUIElementReference)abtractRef.getRef()).getValue();
		}
		return objInQuestion instanceof ContentElement;
	}
	
	private static boolean isRestrictedToContainer(EObject context) {
		while (context instanceof AbstractViewGUIElementRef) {
			context = context.eContainer();
		}
		return validContainerForAbstractViews.contains(context.eClass());
	}
	
	private static boolean isValidViewElement(EObject context, EObject obj) {
		if (obj instanceof ViewElementType) {
			if (isRestrictedToContainer(context)) {
				if (obj instanceof ContentElement) return false;
				else if (obj instanceof ViewGUIElementReference) {
					if (((ViewGUIElementReference) obj).getValue() instanceof ContentElement) return false;
				}
			}
			return true;
		}
		return false;	
	}
}

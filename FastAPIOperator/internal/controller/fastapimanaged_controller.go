/*
Copyright 2025.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package controller

import (
	"context"
	"fmt"
	"reflect"

	appsv1 "k8s.io/api/apps/v1"
	corev1 "k8s.io/api/core/v1"
	apierrors "k8s.io/apimachinery/pkg/api/errors"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/types"
	"k8s.io/apimachinery/pkg/util/intstr"
	"k8s.io/utils/ptr"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/log"

	devv1alpha1 "github.com/PyDataBlog/fastapimanaged-operator/api/v1alpha1"
	gatewayv1 "sigs.k8s.io/gateway-api/apis/v1"
)

// FastAPIManagedReconciler reconciles a FastAPIManaged object
type FastAPIManagedReconciler struct {
	client.Client
	Scheme *runtime.Scheme
}

// +kubebuilder:rbac:groups=dev.web.api,resources=fastapimanageds,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=dev.web.api,resources=fastapimanageds/status,verbs=get;update;patch
// +kubebuilder:rbac:groups=dev.web.api,resources=fastapimanageds/finalizers,verbs=update
// +kubebuilder:rbac:groups="",resources=namespaces,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=apps,resources=deployments,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups="",resources=services,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=gateway.networking.k8s.io,resources=gateways,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=gateway.networking.k8s.io,resources=httproutes,verbs=get;list;watch;create;update;patch;delete

func (r *FastAPIManagedReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	logger := log.FromContext(ctx)
	logger.Info("Reconciling FastAPIManaged")

	// Fetch the FastAPIManaged instance
	cr := &devv1alpha1.FastAPIManaged{}
	if err := r.Get(ctx, req.NamespacedName, cr); err != nil {
		if apierrors.IsNotFound(err) {
			logger.Info("FastAPIManaged resource not found. Ignoring since object must be deleted.")
			return ctrl.Result{}, nil
		}
		logger.Error(err, "Failed to get FastAPIManaged")
		return ctrl.Result{}, err
	}

	// Reconcile Namespace
	if err := r.reconcileNamespace(ctx, cr); err != nil {
		logger.Error(err, "Failed to reconcile Namespace")
		return ctrl.Result{}, err
	}

	// Reconcile Deployment
	if err := r.reconcileDeployment(ctx, cr); err != nil {
		logger.Error(err, "Failed to reconcile Deployment")
		return ctrl.Result{}, err
	}

	// Reconcile Service
	if err := r.reconcileService(ctx, cr); err != nil {
		logger.Error(err, "Failed to reconcile Service")
		return ctrl.Result{}, err
	}

	// Reconcile Gateway
	if err := r.reconcileGateway(ctx, cr); err != nil {
		logger.Error(err, "Failed to reconcile Gateway")
		return ctrl.Result{}, err
	}

	// Reconcile HTTPRoute
	if err := r.reconcileHTTPRoute(ctx, cr); err != nil {
		logger.Error(err, "Failed to reconcile HTTPRoute")
		return ctrl.Result{}, err
	}

	logger.Info("Successfully reconciled FastAPIManaged resources")
	return ctrl.Result{}, nil
}

func (r *FastAPIManagedReconciler) reconcileNamespace(ctx context.Context, cr *devv1alpha1.FastAPIManaged) error {
	logger := log.FromContext(ctx)
	namespaceName := cr.Spec.Namespace

	desiredNs := &corev1.Namespace{
		ObjectMeta: metav1.ObjectMeta{
			Name: namespaceName,
		},
	}

	foundNs := &corev1.Namespace{}
	err := r.Get(ctx, types.NamespacedName{Name: namespaceName}, foundNs)
	if err != nil {
		if apierrors.IsNotFound(err) {
			logger.Info("Creating Namespace", "Namespace.Name", desiredNs.Name)
			return r.Create(ctx, desiredNs)
		}
		return fmt.Errorf("failed to get Namespace %s: %w", namespaceName, err)
	}
	logger.Info("Namespace already exists", "Namespace.Name", foundNs.Name)
	return nil
}

func (r *FastAPIManagedReconciler) reconcileDeployment(ctx context.Context, cr *devv1alpha1.FastAPIManaged) error {
	logger := log.FromContext(ctx)
	deploymentName := cr.Name + "-deployment"
	namespace := cr.Spec.Namespace

	labels := map[string]string{
		"app.kubernetes.io/name":       cr.Spec.ApplicationImage,
		"app.kubernetes.io/instance":   cr.Name,
		"app.kubernetes.io/version":    cr.Spec.APIVersion,
		"app.kubernetes.io/managed-by": "fastapimanaged-operator",
	}

	replicas := cr.Spec.Replicas
	if replicas == nil {
		replicas = ptr.To(int32(1)) // Default if not set by CRD defaulting
	}
	containerPort := cr.Spec.ContainerPort
	if containerPort == nil {
		containerPort = ptr.To(int32(8000)) // Default
	}

	desiredDep := &appsv1.Deployment{
		ObjectMeta: metav1.ObjectMeta{
			Name:      deploymentName,
			Namespace: namespace,
			Labels:    labels,
		},
		Spec: appsv1.DeploymentSpec{
			Replicas: replicas,
			Selector: &metav1.LabelSelector{
				MatchLabels: map[string]string{
					"app.kubernetes.io/name":     cr.Spec.ApplicationImage,
					"app.kubernetes.io/instance": cr.Name,
				},
			},
			Template: corev1.PodTemplateSpec{
				ObjectMeta: metav1.ObjectMeta{
					Labels: map[string]string{
						"app.kubernetes.io/name":     cr.Spec.ApplicationImage,
						"app.kubernetes.io/instance": cr.Name,
					},
				},
				Spec: corev1.PodSpec{
					Containers: []corev1.Container{{
						Name:  cr.Spec.ApplicationImage,
						Image: fmt.Sprintf("%s:%s", cr.Spec.ApplicationImage, cr.Spec.APIVersion),
						Ports: []corev1.ContainerPort{{
							ContainerPort: *containerPort,
							Name:          "http",
						}},
						ImagePullPolicy: corev1.PullIfNotPresent,
						Env: []corev1.EnvVar{
							{Name: "PYTHONUNBUFFERED", Value: "1"},
							{Name: "API_VERSION", Value: cr.Spec.APIVersion},
						},
					}},
				},
			},
		},
	}

	if err := ctrl.SetControllerReference(cr, desiredDep, r.Scheme); err != nil {
		return fmt.Errorf("failed to set owner reference on Deployment: %w", err)
	}

	foundDep := &appsv1.Deployment{}
	err := r.Get(ctx, types.NamespacedName{Name: deploymentName, Namespace: namespace}, foundDep)
	if err != nil {
		if apierrors.IsNotFound(err) {
			logger.Info("Creating Deployment", "Deployment.Namespace", namespace, "Deployment.Name", deploymentName)
			return r.Create(ctx, desiredDep)
		}
		return fmt.Errorf("failed to get Deployment %s/%s: %w", namespace, deploymentName, err)
	}

	// Simple update logic: only update replicas and image if they differ
	if !reflect.DeepEqual(foundDep.Spec.Replicas, desiredDep.Spec.Replicas) ||
		!reflect.DeepEqual(foundDep.Spec.Template.Spec.Containers[0].Image, desiredDep.Spec.Template.Spec.Containers[0].Image) {
		logger.Info("Updating Deployment", "Deployment.Namespace", namespace, "Deployment.Name", deploymentName)
		foundDep.Spec.Replicas = desiredDep.Spec.Replicas
		foundDep.Spec.Template.Spec.Containers[0].Image = desiredDep.Spec.Template.Spec.Containers[0].Image
		// Update other fields as needed, e.g., env vars, ports if they can change
		return r.Update(ctx, foundDep)
	}

	logger.Info("Deployment already up-to-date", "Deployment.Namespace", namespace, "Deployment.Name", deploymentName)
	return nil
}

func (r *FastAPIManagedReconciler) reconcileService(ctx context.Context, cr *devv1alpha1.FastAPIManaged) error {
	logger := log.FromContext(ctx)
	serviceName := cr.Name + "-service"
	namespace := cr.Spec.Namespace

	labels := map[string]string{
		"app.kubernetes.io/name":       cr.Spec.ApplicationImage,
		"app.kubernetes.io/instance":   cr.Name,
		"app.kubernetes.io/managed-by": "fastapimanaged-operator",
	}
	selectorLabels := map[string]string{
		"app.kubernetes.io/name":     cr.Spec.ApplicationImage,
		"app.kubernetes.io/instance": cr.Name,
	}

	servicePort := cr.Spec.ServicePort
	if servicePort == nil {
		servicePort = ptr.To(int32(8000)) // Default
	}
	containerPort := cr.Spec.ContainerPort
	if containerPort == nil {
		containerPort = ptr.To(int32(8000)) // Default
	}

	desiredSvc := &corev1.Service{
		ObjectMeta: metav1.ObjectMeta{
			Name:      serviceName,
			Namespace: namespace,
			Labels:    labels,
		},
		Spec: corev1.ServiceSpec{
			Ports: []corev1.ServicePort{{
				Name:       "http",
				Protocol:   corev1.ProtocolTCP,
				Port:       *servicePort,
				TargetPort: intstr.FromInt32(*containerPort),
			}},
			Selector: selectorLabels,
			Type:     corev1.ServiceTypeClusterIP,
		},
	}

	if err := ctrl.SetControllerReference(cr, desiredSvc, r.Scheme); err != nil {
		return fmt.Errorf("failed to set owner reference on Service: %w", err)
	}

	foundSvc := &corev1.Service{}
	err := r.Get(ctx, types.NamespacedName{Name: serviceName, Namespace: namespace}, foundSvc)
	if err != nil {
		if apierrors.IsNotFound(err) {
			logger.Info("Creating Service", "Service.Namespace", namespace, "Service.Name", serviceName)
			return r.Create(ctx, desiredSvc)
		}
		return fmt.Errorf("failed to get Service %s/%s: %w", namespace, serviceName, err)
	}

	// Simple update: check if ports changed
	if !reflect.DeepEqual(foundSvc.Spec.Ports, desiredSvc.Spec.Ports) || !reflect.DeepEqual(foundSvc.Spec.Selector, desiredSvc.Spec.Selector) {
		logger.Info("Updating Service", "Service.Namespace", namespace, "Service.Name", serviceName)
		foundSvc.Spec.Ports = desiredSvc.Spec.Ports
		foundSvc.Spec.Selector = desiredSvc.Spec.Selector // Selector might change if labels change
		return r.Update(ctx, foundSvc)
	}

	logger.Info("Service already up-to-date", "Service.Namespace", namespace, "Service.Name", serviceName)
	return nil
}

func (r *FastAPIManagedReconciler) reconcileGateway(ctx context.Context, cr *devv1alpha1.FastAPIManaged) error {
	logger := log.FromContext(ctx)
	gatewayName := cr.Name + "-gateway"
	namespace := cr.Spec.Namespace

	labels := map[string]string{
		"app.kubernetes.io/name":       cr.Spec.ApplicationImage,
		"app.kubernetes.io/instance":   cr.Name,
		"app.kubernetes.io/managed-by": "fastapimanaged-operator",
	}

	gatewayHostname := gatewayv1.Hostname(fmt.Sprintf("%s.nip.io", cr.Spec.IngressIP))

	desiredGw := &gatewayv1.Gateway{
		ObjectMeta: metav1.ObjectMeta{
			Name:      gatewayName,
			Namespace: namespace,
			Labels:    labels,
		},
		Spec: gatewayv1.GatewaySpec{
			GatewayClassName: gatewayv1.ObjectName(cr.Spec.GatewayClassName),
			Listeners: []gatewayv1.Listener{{
				Name:     gatewayv1.SectionName("http"),
				Hostname: &gatewayHostname,
				Port:     gatewayv1.PortNumber(80),
				Protocol: gatewayv1.HTTPProtocolType,
				AllowedRoutes: &gatewayv1.AllowedRoutes{
					Namespaces: &gatewayv1.RouteNamespaces{
						From: ptr.To(gatewayv1.NamespacesFromAll),
					},
				},
			}},
		},
	}

	if err := ctrl.SetControllerReference(cr, desiredGw, r.Scheme); err != nil {
		return fmt.Errorf("failed to set owner reference on Gateway: %w", err)
	}

	foundGw := &gatewayv1.Gateway{}
	err := r.Get(ctx, types.NamespacedName{Name: gatewayName, Namespace: namespace}, foundGw)
	if err != nil {
		if apierrors.IsNotFound(err) {
			logger.Info("Creating Gateway", "Gateway.Namespace", namespace, "Gateway.Name", gatewayName)
			return r.Create(ctx, desiredGw)
		}
		return fmt.Errorf("failed to get Gateway %s/%s: %w", namespace, gatewayName, err)
	}

	if !reflect.DeepEqual(foundGw.Spec, desiredGw.Spec) {
		logger.Info("Updating Gateway", "Gateway.Namespace", namespace, "Gateway.Name", gatewayName)
		foundGw.Spec = desiredGw.Spec
		return r.Update(ctx, foundGw)
	}

	logger.Info("Gateway already up-to-date", "Gateway.Namespace", namespace, "Gateway.Name", gatewayName)
	return nil
}

func (r *FastAPIManagedReconciler) reconcileHTTPRoute(ctx context.Context, cr *devv1alpha1.FastAPIManaged) error {
	logger := log.FromContext(ctx)
	httpRouteName := cr.Name + "-httproute"
	namespace := cr.Spec.Namespace
	serviceName := cr.Name + "-service" // Assumes service is named this way

	labels := map[string]string{
		"app.kubernetes.io/name":       cr.Spec.ApplicationImage,
		"app.kubernetes.io/instance":   cr.Name,
		"app.kubernetes.io/managed-by": "fastapimanaged-operator",
	}

	servicePort := cr.Spec.ServicePort
	if servicePort == nil {
		servicePort = ptr.To(int32(8000)) // Default
	}
	portNumber := gatewayv1.PortNumber(*servicePort)

	desiredRoute := &gatewayv1.HTTPRoute{
		ObjectMeta: metav1.ObjectMeta{
			Name:      httpRouteName,
			Namespace: namespace,
			Labels:    labels,
		},
		Spec: gatewayv1.HTTPRouteSpec{
			CommonRouteSpec: gatewayv1.CommonRouteSpec{
				ParentRefs: []gatewayv1.ParentReference{{
					Name:      gatewayv1.ObjectName(cr.Name + "-gateway"), // Assumes gateway is named this way
					Namespace: ptr.To(gatewayv1.Namespace(namespace)),
				}},
			},
			Rules: []gatewayv1.HTTPRouteRule{{
				Matches: []gatewayv1.HTTPRouteMatch{{
					Path: &gatewayv1.HTTPPathMatch{
						Type:  ptr.To(gatewayv1.PathMatchPathPrefix),
						Value: ptr.To(cr.Spec.HTTPRoutePathPrefix),
					},
				}},
				BackendRefs: []gatewayv1.HTTPBackendRef{{
					BackendRef: gatewayv1.BackendRef{
						BackendObjectReference: gatewayv1.BackendObjectReference{
							Name: gatewayv1.ObjectName(serviceName),
							Port: &portNumber,
						},
					},
				}},
			}},
		},
	}

	if err := ctrl.SetControllerReference(cr, desiredRoute, r.Scheme); err != nil {
		return fmt.Errorf("failed to set owner reference on HTTPRoute: %w", err)
	}

	foundRoute := &gatewayv1.HTTPRoute{}
	err := r.Get(ctx, types.NamespacedName{Name: httpRouteName, Namespace: namespace}, foundRoute)
	if err != nil {
		if apierrors.IsNotFound(err) {
			logger.Info("Creating HTTPRoute", "HTTPRoute.Namespace", namespace, "HTTPRoute.Name", httpRouteName)
			return r.Create(ctx, desiredRoute)
		}
		return fmt.Errorf("failed to get HTTPRoute %s/%s: %w", namespace, httpRouteName, err)
	}

	if !reflect.DeepEqual(foundRoute.Spec, desiredRoute.Spec) {
		logger.Info("Updating HTTPRoute", "HTTPRoute.Namespace", namespace, "HTTPRoute.Name", httpRouteName)
		foundRoute.Spec = desiredRoute.Spec
		return r.Update(ctx, foundRoute)
	}

	logger.Info("HTTPRoute already up-to-date", "HTTPRoute.Namespace", namespace, "HTTPRoute.Name", httpRouteName)
	return nil
}

// SetupWithManager sets up the controller with the Manager.
func (r *FastAPIManagedReconciler) SetupWithManager(mgr ctrl.Manager) error {
	return ctrl.NewControllerManagedBy(mgr).
		For(&devv1alpha1.FastAPIManaged{}).
		Owns(&appsv1.Deployment{}).
		Owns(&corev1.Service{}).
		Owns(&gatewayv1.Gateway{}).
		Owns(&gatewayv1.HTTPRoute{}).
		// We don't Owns(&corev1.Namespace{}) because Namespaces are cluster-scoped
		// and cannot be owned by a namespaced CR in the typical way.
		// If the Namespace is deleted, the FastAPIManaged CR might need a finalizer
		// or other logic to handle cleanup or re-creation if desired.
		Complete(r)
}

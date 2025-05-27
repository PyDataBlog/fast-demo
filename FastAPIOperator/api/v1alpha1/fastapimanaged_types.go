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

package v1alpha1

import (
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// FastAPIManagedSpec defines the desired state of FastAPIManaged
type FastAPIManagedSpec struct {
	// INSERT ADDITIONAL SPEC FIELDS - desired state of cluster
	// Important: Run "make" to regenerate code after modifying this file

	// Namespace is the Kubernetes namespace where all resources will be deployed.
	// +kubebuilder:validation:Required
	// +kubebuilder:validation:MinLength=1
	Namespace string `json:"namespace"`

	// ApplicationImage is the base name of the Docker image for the application.
	// Example: "fast-demo"
	// +kubebuilder:validation:Required
	// +kubebuilder:validation:MinLength=1
	ApplicationImage string `json:"applicationImage"`

	// APIVersion is the version tag for the Docker image and used in various configurations.
	// Example: "v21", "beta01"
	// +kubebuilder:validation:Required
	// +kubebuilder:validation:MinLength=1
	APIVersion string `json:"apiVersion"`

	// Replicas is the number of desired pods for the Deployment.
	// +kubebuilder:validation:Optional
	// +kubebuilder:default:=1
	// +kubebuilder:validation:Minimum=0
	Replicas *int32 `json:"replicas,omitempty"`

	// IngressIP is the IP address to be used for the Gateway hostname.
	// This will be used to construct the hostname like "<IngressIP>.nip.io".
	// +kubebuilder:validation:Required
	// +kubebuilder:validation:Pattern=`^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$`
	IngressIP string `json:"ingressIP"`

	// GatewayClassName is the name of the GatewayClass to be used by the Gateway resource.
	// Example: "nginx"
	// +kubebuilder:validation:Optional
	// +kubebuilder:default:="nginx"
	GatewayClassName string `json:"gatewayClassName,omitempty"`

	// HTTPRoutePathPrefix is the path prefix for the HTTPRoute rule.
	// Example: "/api"
	// +kubebuilder:validation:Optional
	// +kubebuilder:default:="/api"
	HTTPRoutePathPrefix string `json:"httpRoutePathPrefix,omitempty"`

	// ServicePort is the port on which the Service will expose the application.
	// +kubebuilder:validation:Optional
	// +kubebuilder:default:=8000
	// +kubebuilder:validation:Minimum=1
	// +kubebuilder:validation:Maximum=65535
	ServicePort *int32 `json:"servicePort,omitempty"`

	// ContainerPort is the port the application container listens on.
	// +kubebuilder:validation:Optional
	// +kubebuilder:default:=8000
	// +kubebuilder:validation:Minimum=1
	// +kubebuilder:validation:Maximum=65535
	ContainerPort *int32 `json:"containerPort,omitempty"`
}

// FastAPIManagedStatus defines the observed state of FastAPIManaged
type FastAPIManagedStatus struct {
	// INSERT ADDITIONAL STATUS FIELD - define observed state of cluster
	// Important: Run "make" to regenerate code after modifying this file

	// Conditions represent the latest available observations of an object's state.
	// +operator-sdk:csv:customresourcedefinitions:type=status
	Conditions []metav1.Condition `json:"conditions,omitempty" patchStrategy:"merge" patchMergeKey:"type" protobuf:"bytes,1,rep,name=conditions"`
}

//+kubebuilder:object:root=true
//+kubebuilder:subresource:status

// FastAPIManaged is the Schema for the fastapimanageds API
type FastAPIManaged struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	Spec   FastAPIManagedSpec   `json:"spec,omitempty"`
	Status FastAPIManagedStatus `json:"status,omitempty"`
}

//+kubebuilder:object:root=true

// FastAPIManagedList contains a list of FastAPIManaged
type FastAPIManagedList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`
	Items           []FastAPIManaged `json:"items"`
}

func init() {
	SchemeBuilder.Register(&FastAPIManaged{}, &FastAPIManagedList{})
}

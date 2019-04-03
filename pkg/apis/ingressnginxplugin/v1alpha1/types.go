package v1alpha1

import metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"

// +genclient
// +k8s:deepcopy-gen:interfaces=k8s.io/apimachinery/pkg/runtime.Object

// IngressNginxPluginis a top-level type
type IngressNginxPlugin struct {
	metav1.TypeMeta `json:",inline"`
	// +optional
	metav1.ObjectMeta `json:"metadata,omitempty"`

	// +optional
	// Status HelloTypeStatus `json:"status,omitempty"`
	// This is where you can define
	// your own custom spec
	Spec IngressNginxPluginSpec `json:"spec,omitempty"`
}

// custom spec
type IngressNginxPluginSpec struct {
	Archive   string `json:"archive,omitempty"`
	Sha256Sum string `json:"sha256sum,omitempty"`
	//Vars      map[string]interface{} `json:"vars,"`
}

// +k8s:deepcopy-gen:interfaces=k8s.io/apimachinery/pkg/runtime.Object

// no client needed for list as it's been created in above
type IngressNginxPluginList struct {
	metav1.TypeMeta `json:",inline"`
	// +optional
	metav1.ListMeta `json:"metadata,omitempty"`

	Items []IngressNginxPlugin `json:"items"`
}

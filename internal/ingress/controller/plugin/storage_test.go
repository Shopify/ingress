package plugin

import (
	"fmt"
	"testing"
)

// func Test_Setup(t *testing.T) {
//
// 	u := "gs://ingress-nginx-lua-plugins/plugins-c7b685addc45c47e5373081e57786380f9fcbcbe.tar.gz"
// 	sha256 := "cb1fdc02756065df38d695e50519d6260ef261ad79b17198f15c78b391662c1d"
// 	installDirectory, _ := ioutil.TempDir("", "")
// 	fmt.Printf("install directory is: %s\n", installDirectory)
//
// 	err := Setup(u, sha256, installDirectory)
// 	if err != nil {
// 		t.Fatal(err)
// 	}
// }

type dummyProvider struct{}

func (p *dummyProvider) Fetch(archiveURL string) (string, error) {
	return "", nil
}

func Test_provider(t *testing.T) {

	// Override providers
	providers = map[string]storageProvider{
		"gs":   &dummyProvider{},
		"http": &dummyProvider{},
	}

	testCases := []struct {
		archiveURL       string
		expectedProvider storageProvider
		expectedErr      error
	}{
		{
			archiveURL:       "gs://bucket/file",
			expectedProvider: providers["gs"],
			expectedErr:      nil,
		},
		{
			archiveURL:       "http://bucket/file",
			expectedProvider: providers["http"],
			expectedErr:      nil,
		},
		{
			archiveURL:       "s3://bucket/file",
			expectedProvider: nil,
			expectedErr:      fmt.Errorf("unknown storage provider 's3'"),
		},
	}

	for _, c := range testCases {
		p, err := provider(c.archiveURL)
		if err != nil {
			if c.expectedErr != nil {
				if err.Error() != c.expectedErr.Error() {
					t.Errorf("unexpected err, got %v, expected %v", err, c.expectedErr)
					continue
				}
				continue
			}

			t.Errorf("unexpected err, got %v", err)
			continue
		}

		if p != c.expectedProvider {
			t.Errorf("unexpected provider, got %v, expected %v", p, c.expectedProvider)
		}
	}
}

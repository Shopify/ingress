package plugin

import "testing"

func Test_gcsProvider_Parse(t *testing.T) {
	p := &gcsProvider{}

	testCases := []struct {
		archiveURL       string
		expectedBucket   string
		expectedFilename string
		expectedErr      error
	}{
		{
			archiveURL:       "gs://my-bucket/myfile.tar.gz",
			expectedBucket:   "my-bucket",
			expectedFilename: "myfile.tar.gz",
			expectedErr:      nil,
		},
		{
			archiveURL:       "gs://my-bucket/sub_directory/myfile.tar.gz",
			expectedBucket:   "my-bucket",
			expectedFilename: "sub_directory/myfile.tar.gz",
			expectedErr:      nil,
		},
		{
			archiveURL:  "gs://my-bucket/",
			expectedErr: ErrInvalidGCSURL,
		},

		{
			archiveURL:  "http://localhost/myfile.tar.gz",
			expectedErr: ErrInvalidGCSURL,
		},
	}

	for _, c := range testCases {

		bucket, filename, err := p.Parse(c.archiveURL)
		if err != c.expectedErr {
			t.Errorf("unexpected err, got %v, expected %v", err, c.expectedErr)
		}
		if c.expectedErr != nil {
			continue
		}
		if bucket != c.expectedBucket {
			t.Errorf("unexpected bucket, got %v, expected %v", bucket, c.expectedBucket)
		}

		if filename != c.expectedFilename {
			t.Errorf("unexpected filename, got %v, expected %v", filename, c.expectedFilename)
		}

	}

}

class Atmos < Formula
  desc "Universal Tool for DevOps and Cloud Automation"
  homepage "https://github.com/cloudposse/atmos"
  url "https://github.com/cloudposse/atmos/archive/v1.10.1.tar.gz"
  sha256 "64ab3244937568ce9f88594e14ab06390828955cd207a359527293dcee5bf1f4"
  license "Apache-2.0"

  bottle do
    sha256 cellar: :any_skip_relocation, arm64_monterey: "2f6beb2d64d329a3c4bfadb57ffe268248b12f9184a6e4fbbd5d24f69ef8e0b5"
    sha256 cellar: :any_skip_relocation, arm64_big_sur:  "2e195884bb4b02571860f2d2adacd159ca35e2752ed329b8d33b58e1118fd403"
    sha256 cellar: :any_skip_relocation, monterey:       "c747ddf881958301d35bb2bb6d44c978c8388f5f9066cebd075f8df6e3da6305"
    sha256 cellar: :any_skip_relocation, big_sur:        "b1463a31d3917ac02746153bf75e3408a2d4ebf74a1399f2420d48471d675083"
    sha256 cellar: :any_skip_relocation, catalina:       "c0aab468e7087f2fb874bf3969aab4928bb70302ef4b026ce09af9e69e3c9564"
    sha256 cellar: :any_skip_relocation, x86_64_linux:   "2625f367cd0d6bb8faead35ac34c05f014dcc834a771f8b9a8a6955c3d22903f"
  end

  depends_on "go" => :build

  def install
    system "go", "build", *std_go_args(ldflags: "-s -w -X 'github.com/cloudposse/atmos/cmd.Version=#{version}'")

    generate_completions_from_executable(bin/"atmos", "completion")
  end

  test do
    # create basic atmos.yaml
    (testpath/"atmos.yaml").write <<~EOT
      components:
        terraform:
          base_path: "./components/terraform"
          apply_auto_approve: false
          deploy_run_init: true
          auto_generate_backend_file: false
        helmfile:
          base_path: "./components/helmfile"
          kubeconfig_path: "/dev/shm"
          helm_aws_profile_pattern: "{namespace}-{tenant}-gbl-{stage}-helm"
          cluster_name_pattern: "{namespace}-{tenant}-{environment}-{stage}-eks-cluster"
      stacks:
        base_path: "./stacks"
        included_paths:
          - "**/*"
        excluded_paths:
          - "globals/**/*"
          - "catalog/**/*"
          - "**/*globals*"
        name_pattern: "{tenant}-{environment}-{stage}"
      logs:
        verbose: false
        colors: true
    EOT

    # create scaffold
    mkdir_p testpath/"stacks"
    mkdir_p testpath/"components/terraform/top-level-component1"
    (testpath/"stacks/tenant1-ue2-dev.yaml").write <<~EOT
      terraform:
        backend_type: s3 # s3, remote, vault, static, etc.
        backend:
          s3:
            encrypt: true
            bucket: "eg-ue2-root-tfstate"
            key: "terraform.tfstate"
            dynamodb_table: "eg-ue2-root-tfstate-lock"
            acl: "bucket-owner-full-control"
            region: "us-east-2"
            role_arn: null
          remote:
          vault:

      vars:
        tenant: tenant1
        region: us-east-2
        environment: ue2
        stage: dev

      components:
        terraform:
          top-level-component1: {}
    EOT

    # create expected file
    (testpath/"backend.tf.json").write <<~EOT
      {
        "terraform": {
          "backend": {
            "s3": {
              "workspace_key_prefix": "top-level-component1",
              "acl": "bucket-owner-full-control",
              "bucket": "eg-ue2-root-tfstate",
              "dynamodb_table": "eg-ue2-root-tfstate-lock",
              "encrypt": true,
              "key": "terraform.tfstate",
              "region": "us-east-2",
              "role_arn": null
            }
          }
        }
      }
    EOT

    system bin/"atmos", "terraform", "generate", "backend", "top-level-component1", "--stack", "tenant1-ue2-dev"
    actual_json = JSON.parse(File.read(testpath/"components/terraform/top-level-component1/backend.tf.json"))
    expected_json = JSON.parse(File.read(testpath/"backend.tf.json"))
    assert_equal expected_json["terraform"].to_set, actual_json["terraform"].to_set
  end
end

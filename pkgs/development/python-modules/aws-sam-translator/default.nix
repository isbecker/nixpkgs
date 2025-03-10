{ lib
, boto3
, buildPythonPackage
, enum34
, fetchFromGitHub
, jsonschema
, mock
, parameterized
, pytestCheckHook
, pythonOlder
, pyyaml
, six
}:

buildPythonPackage rec {
  pname = "aws-sam-translator";
  version = "1.39.0";

  src = fetchFromGitHub {
    owner = "aws";
    repo = "serverless-application-model";
    rev = "v${version}";
    sha256 = "1a9m7zyqc414adw1i0sr2n9nlnmry0gi1ah1qna3yv9dx4ql9v9c";
  };

  propagatedBuildInputs = [
    boto3
    jsonschema
    six
  ] ++ lib.optionals (pythonOlder "3.4") [
    enum34
  ];

  postPatch = ''
    substituteInPlace pytest.ini \
      --replace " --cov samtranslator --cov-report term-missing --cov-fail-under 95" ""
  '';

  checkInputs = [
    mock
    parameterized
    pytestCheckHook
    pyyaml
  ];

  pythonImportsCheck = [ "samtranslator" ];

  meta = with lib; {
    description = "Python library to transform SAM templates into AWS CloudFormation templates";
    homepage = "https://github.com/awslabs/serverless-application-model";
    license = licenses.asl20;
    maintainers = with maintainers; [ ];
  };
}

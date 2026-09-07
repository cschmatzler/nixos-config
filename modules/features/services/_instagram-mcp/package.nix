{
  fetchFromGitHub,
  python3Packages,
}: let
  instagrapi = python3Packages.buildPythonPackage {
    pname = "instagrapi";
    version = "2.18.18";
    pyproject = true;
    src = python3Packages.fetchPypi {
      pname = "instagrapi";
      version = "2.18.18";
      hash = "sha256-FIy7Yqwgu8S92xWz34yNdfoIqAkLCvw2xsgV30SZF4g=";
    };
    build-system = with python3Packages; [setuptools wheel];
    dependencies = with python3Packages; [
      requests
      pysocks
      pydantic
      pillow
      pycryptodomex
      moviepy
    ];
    doCheck = false;
  };
in
  python3Packages.buildPythonPackage {
    pname = "instagram-mcp-server";
    version = "1.0.0-unstable-2026-06-20";
    pyproject = true;
    src = fetchFromGitHub {
      owner = "official-Arvind";
      repo = "instagram-mcp";
      rev = "199524b596884de350a4fdf71dfa18ed027d5957";
      hash = "sha256-3kkG6qxmEk3bBLYShufxVTF2+wPiHEaGyDGoxFrmchI=";
    };
    build-system = with python3Packages; [setuptools wheel];
    dependencies = with python3Packages; [fastmcp instagrapi pillow requests];
    doCheck = false;
  }

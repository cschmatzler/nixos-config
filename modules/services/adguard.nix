{
  services.adguardhome = {
    enable = true;
    port = 10000;
    settings = {
      dns = {
        upstream_dns = [
          "1.1.1.1"
          "1.0.0.1"
        ];
      };
      filtering = {
        protection_enabled = true;
        filtering_enabled = true;
        safe_search = {
          enabled = false;
        };
      };
    };
  };
}

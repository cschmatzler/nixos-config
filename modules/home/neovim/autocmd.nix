{
  programs.nixvim = {
    autoGroups = {
      Christoph = {};
    };

    autoCmd = [
      {
        event = "BufWritePre";
        group = "Christoph";
        pattern = "*";
        command = "%s/\\s\\+$//e";
      }
      {
        event = "BufReadPost";
        group = "Christoph";
        pattern = "*";
        command = "normal zR";
      }
      {
        event = "FileReadPost";
        group = "Christoph";
        pattern = "*";
        command = "normal zR";
      }
      {
        event = "FileType";
        group = "Christoph";
        pattern = "*.ex,*.exs,*.heex";
        command = "setlocal expandtab tabstop=2 shiftwidth=2 softtabstop=2";
      }
    ];
  };
}

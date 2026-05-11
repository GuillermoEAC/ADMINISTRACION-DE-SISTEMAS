<?php
  $config['db_dsnw'] = 'mysql://roundcube_user:RoundcubePasswordSegura2026@roundcube-db:3306/roundcubemail';
  $config['db_dsnr'] = '';
  $config['imap_host'] = 'tls://mailserver:143';
  $config['smtp_host'] = 'tls://mailserver:587';
  $config['username_domain'] = '';
  $config['temp_dir'] = '/tmp/roundcube-temp';
  $config['skin'] = 'elastic';
  $config['request_path'] = '/';
  $config['plugins'] = array_filter(array_unique(array_merge($config['plugins'], ['archive', 'zipdownload'])));
  

moment.locale 'zh-cn'

try
  @m_favs = JSON.parse(localStorage.favs)||{}
catch
  @m_favs = {}
@refresh_favs = =>
  $ '#favs'
    .empty()
  for k, fav of @m_favs
    fav.origin ?= "http://#{fav.bucket}.b0.upaiyun.com"
    $ li = document.createElement 'li'
      .appendTo '#favs'
    $ document.createElement 'a'
      .appendTo li
      .text "#{k} (#{fav.origin})"
      .attr href: '#'
      .data 'fav', fav
      .click (ev)=>
        ev.preventDefault()
        $(ev.currentTarget).parent().addClass('active').siblings().removeClass 'active'
        for k, v of $(ev.currentTarget).data 'fav'
          $ "#input#{_.capitalize k}"
            .val v
        $ '#formLogin'
          .submit()
    $ document.createElement 'button'
      .appendTo li
      .prepend @createIcon 'trash-o'
      .addClass 'btn btn-danger btn-xs'
      .attr 'title', '删除这条收藏记录'
      .tooltip placement: 'bottom'
      .data 'fav', fav
      .click (ev)=>
        fav = $(ev.currentTarget).data 'fav'
        delete @m_favs["#{fav.username}@#{fav.bucket}"]
        localStorage.favs = JSON.stringify @m_favs
        @refresh_favs()
@humanFileSize = (bytes, si) ->
  thresh = (if si then 1000 else 1024)
  return bytes + " B"  if bytes < thresh
  units = (if si then [
    "kB"
    "MB"
    "GB"
    "TB"
    "PB"
    "EB"
    "ZB"
    "YB"
  ] else [
    "KiB"
    "MiB"
    "GiB"
    "TiB"
    "PiB"
    "EiB"
    "ZiB"
    "YiB"
  ])
  u = -1
  loop
    bytes /= thresh
    ++u
    break unless bytes >= thresh
  bytes.toFixed(1) + " " + units[u]

@_upyun_api = (opt, cb)=>
  opt.headers?= {}
  opt.headers["Content-Length"] = String opt.length || opt.data?.length || 0 unless opt.method in ['GET', 'HEAD']
  date = new Date().toUTCString()
  if @password.match /^MD5_/
    md5_password = @password.replace /^MD5_/, ''
  else
    md5_password = MD5 @password
  signature = "#{opt.method}&/#{@bucket}#{opt.url}&#{date}"
  signature = Crypto.createHmac('sha1', md5_password).update(signature).digest('base64')

  opt.headers["Authorization"] = "UPYUN #{@username}:#{signature}"
  opt.headers["Date"] = date
  @_upyun_api_req = req = CallRequest
    options: 
      method: opt.method
      url: "http://v0.api.upyun.com/#{@bucket}#{opt.url}"
      headers: opt.headers
      body: opt.data
    onData: opt.onData
    onRequestData: opt.onRequestData
    pipeRequest: opt.pipeRequest
    pipeResponse: opt.pipeResponse
    onFinish: (e, res, data)=>
      return cb e if e
      if res.statusCode == 200
        cb null, data
      else
        status = null
        try
          status = JSON.parse(data) if data
        if status && status.msg
          cb new Error status.msg
        else
          cb new Error "未知错误 (HTTP#{res.statusCode})"
  return =>
    req.abort()
    cb new Error '操作已取消'

@upyun_api = (opt, cb)=>
  start = Date.now()
  @_upyun_api opt, (e, data)=>
    console?.log "#{opt.method} #{@bucket}#{opt.url} done (+#{Date.now() - start}ms)"
    cb e, data

Messenger.options = 
  extraClasses: 'messenger-fixed messenger-on-bottom messenger-on-right'
  theme: 'future'
  messageDefaults:
    showCloseButton: true
    hideAfter: 10
    retry:
      label: '重试'
      phrase: 'TIME秒钟后重试'
      auto: true
      delay: 5
@createIcon = (icon)=>
  $ document.createElement 'i'
    .addClass "fa fa-#{icon}"
@shortOperation = (title, operation)=>
  @shortOperationBusy = true
  $ '#loadingText'
    .text title||''
    .append '<br />'
  $ 'body'
    .addClass 'loading'
  $ btnCancel = document.createElement 'button'
    .appendTo '#loadingText'
    .addClass 'btn btn-default btn-xs btn-inline'
    .text '取消'
    .hide()
  operationDone = (e)=>
    @shortOperationBusy = false
    $ 'body'
      .removeClass 'loading'
    if e
      msg = Messenger().post
        type: 'error'
        message: e.message
        showCloseButton: true
        actions: 
          ok:
            label: '确定'
            action: =>
              msg.hide()
          retry:
            label: '重试'
            action: =>
              msg.hide()
              @shortOperation title, operation
  operation operationDone, $ btnCancel
      
@taskOperation = (title, operation)=>
  msg = Messenger(
      instance: @messengerTasks
      extraClasses: 'messenger-fixed messenger-on-left messenger-on-bottom'
    ).post 
    hideAfter: 0
    message: title
    actions:
      cancel:
        label: '取消'
        action: =>
  $progresslabel1 = $ document.createElement 'span'
    .appendTo msg.$message.find('.messenger-message-inner')
    .addClass 'pull-right'
  $progressbar = $ document.createElement 'div'
    .appendTo msg.$message.find('.messenger-message-inner')
    .addClass 'progress progress-striped active'
    .css margin: 0
    .append $(document.createElement 'div').addClass('progress-bar').width '100%'
    .append $(document.createElement 'div').addClass('progress-bar progress-bar-success').width '0%'
  $progresslabel2 = $ document.createElement 'div'
    .appendTo msg.$message.find('.messenger-message-inner')
  operationProgress = (progress, progresstext)=>
    $progresslabel2.text progresstext if progresstext
    $progresslabel1.text "#{progress}%" if progress?
    $progressbar
      .toggleClass 'active', !progress?
    $progressbar.children ':not(.progress-bar-success)'
      .toggle !progress?
    $progressbar.children '.progress-bar-success'
      .toggle progress?
      .width "#{progress}%"
  operationDone = (e)=>
    return unless msg
    if e
      msg.update
        type: 'error'
        message: e.message
        showCloseButton: true
        actions: 
          ok:
            label: '确定'
            action: =>
              msg.hide()
          retry:
            label: '重试'
            action: =>
              msg.hide()
              @taskOperation title, operation
    else
      msg.hide()
  operationProgress null
  operation operationProgress, operationDone, msg.$message.find('[data-action="cancel"] a')

@upyun_readdir = (url, cb)=>
  @upyun_api 
    method: "GET"
    url: url
    , (e, data)=>
      return cb e if e
      files = data.split('\n').map (line)-> 
        line = line.split '\t'
        return null unless line.length == 4
        return (
          filename: line[0]
          url: url + encodeURIComponent line[0]
          isDirectory: line[1]=='F'
          length: Number line[2]
          mtime: 1000 * Number line[3]
        )
      cb null, files.filter (file)-> file?
@upyun_find_abort = ->
@upyun_find = (url, cb)=>
  results = []
  @upyun_find_abort = @upyun_readdir url, (e, files)=>
    return cb e if e
    async.eachSeries files, (file, doneEach)=>
        if file.isDirectory
          @upyun_find file.url + '/', (e, tmp)=>
            return doneEach e if e
            results.push item for item in tmp
            results.push file
            doneEach null
        else
          results.push file
          _.defer => doneEach null
      , (e)=> 
        @upyun_find_abort = ->
        cb e, results
@upyun_upload = (url, files, onProgress, cb)=>
  aborted = false
  api_aborting = null
  aborting = =>
    aborted = true
    api_aborting?()
  status = 
    total_files: files.length
    total_bytes: files.reduce ((a, b)-> a + b.length), 0
    current_files: 0
    current_bytes: 0
 
  async.eachSeries files, (file, doneEach)=>
      Fs.stat file.path, (e, stats)=>
        return doneEach (new Error '操作已取消') if aborted
        return doneEach e if e
        api_aborting = @upyun_api
            pipeRequest: file.path
            method: "PUT"
            headers:
              'mkdir': 'true',
            length: stats.size
            url: url + file.url
            onRequestData: (data)=>
              status.current_bytes+= data.length
              onProgress status
          , (e)=>
            status.current_files+= 1
            onProgress status
            doneEach e
    , (e)=>
      cb e

  return aborting
@action_downloadFolder = (filename, url)=>
  unless filename || filename = url.match(/([^\/]+)\/$/)?[1]
    filename = @bucket
    
  @shortOperation "正在列出目录 #{filename} 下的所有文件", (doneFind, $btnCancelFind)=>
    $btnCancelFind.show().click => @upyun_find_abort()
    @upyun_find url, (e, files)=>
      doneFind e
      unless e
        SelectFolder (savepath)=>
          @taskOperation "正在下载目录 #{filename} ...", (progressTransfer, doneTransfer, $btnCancelTransfer)=>
            total_files = files.length
            total_bytes = files.reduce ((a, b)-> a + b.length), 0
            current_files = 0
            current_bytes = 0
            aborting = null
            $btnCancelTransfer.click =>
              aborting() if aborting?
            async.eachSeries files, ((file, doneEach)=>
              return (_.defer => doneEach null) if file.isDirectory
              segs = file.url.substring(url.length).split '/'
              segs = segs.map decodeURIComponent
              destpath = Path.join savepath, filename, Path.join.apply Path, segs

              Mkdirp Path.dirname(destpath), (e)=>
                return doneEach e if e
                _.defer =>
                  bytesWritten = 0
                  current_files+= 1
                  aborting = @upyun_api 
                    method: 'GET'
                    url: file.url
                    pipeResponse: destpath
                    onData: (data)=>
                      bytesWritten += data.length
                      progressTransfer (Math.floor 100 * (current_bytes + bytesWritten) / total_bytes), "已下载：#{current_files} / #{total_files} (#{@humanFileSize current_bytes + bytesWritten} / #{@humanFileSize total_bytes})"
                    , (e)=>
                      current_bytes+= file.length unless e
                      doneEach e

              ), (e)=> 
                aborting = null
                doneTransfer e
                unless e
                  msg = Messenger().post
                    message: "目录 #{filename} 下载完毕"
                    actions: 
                      ok:
                        label: '确定'
                        action: =>
                          msg.hide()
                      open: 
                        label: "打开"
                        action: => 
                          msg.hide()
                          Electron.shell.openItem savepath
@action_uploadFile = (filepath, filename, destpath)=>
  @taskOperation "正在上传 #{filename}", (progressTransfer, doneTransfer, $btnCancelTransfer)=>
    files = []
    loadfileSync = (file)=>
      stat = Fs.statSync(file.path)
      if stat.isFile()
        file.length = stat.size
        files.push file 
      if stat.isDirectory()
        for filename in Fs.readdirSync file.path
          loadfileSync 
            path: Path.join(file.path, filename)
            url: file.url + '/' + encodeURIComponent filename
    try
      loadfileSync path: filepath, url: ''
    catch e
      return doneTransfer e if e
    $btnCancelTransfer.show().click @upyun_upload destpath, files, (status)=>
        progressTransfer (Math.floor 100 * status.current_bytes / status.total_bytes), "已上传：#{status.current_files} / #{status.total_files} (#{@humanFileSize status.current_bytes} / #{@humanFileSize status.total_bytes})"
      , (e)=>
        doneTransfer e
        unless e
          @m_changed_path = destpath.replace /[^\/]+$/, ''
          msg = Messenger().post
            message: "文件 #{filename} 上传完毕"
            actions: 
              ok:
                label: '确定'
                action: =>
                  msg.hide()
@action_show_url = (title, url)=>  
  msg = Messenger().post
    message: "#{title}<pre>#{url}</pre>"
    actions: 
      ok:
        label: '确定'
        action: =>
          msg.hide()
      copy:
        label: '将该地址复制到剪切版'
        action: (ev)=>
          $(ev.currentTarget).text '已复制到剪切版'
          Electron.clipboard.writeText url
@action_share = (url)=>
  url = "upyun://#{@username}:#{@password}@#{@bucket}#{url}"
  msg = Messenger().post
    message: """
      您可以通过以下地址向其他人分享该目录：
      <pre>#{url}</pre>
      注意：<ol>
        <li>该地址中包含了当前操作员的授权信息，向他人分享该地址的同时，也同时分享了该操作员的身份。</li>
        <li>当他人安装了“又拍云管理器时”后，便可以直接点击该链接以打开。</li>
      </ol>
      """
    actions: 
      ok:
        label: '确定'
        action: =>
          msg.hide()
      copy:
        label: '将该地址复制到剪切版'
        action: (ev)=>
          $(ev.currentTarget).text '已复制到剪切版'
          Electron.clipboard.writeText url, 'text'

@jump_login = =>
  @m_path = '/'
  @m_active = false
  @refresh_favs()
  $ '#filelist, #editor'
    .hide()
  $ '#login'
    .fadeIn()

@jump_filelist = =>
  @jump_path '/'  
@jump_path = (path)=>
  @m_path = path
  @m_changed_path = path
  @m_active = true
  @m_files = null
  $ '#filelist .preloader'
    .css
      opacity: 1
  $ '#inputFilter'
    .val ''
  $ '#login, #editor'
    .hide()
  $ '#filelist'
    .fadeIn()
  segs = $.makeArray(@m_path.match /\/[^\/]+/g).map (match)-> String(match).replace /^\//, ''
  segs = segs.map decodeURIComponent
  $ '#path'
    .empty()
  $ li = document.createElement 'li'
    .appendTo '#path'
  $ document.createElement 'a'
    .appendTo li
    .text @username
    .prepend @createIcon 'user'
    .attr 'href', '#'
    .click (ev)=>
      ev.preventDefault()
      @jump_login()
  $ li = document.createElement 'li'
    .toggleClass 'active', !segs.length
    .appendTo '#path'
  $ document.createElement 'a'
    .appendTo li
    .text "#{@bucket} (#{@origin})"
    .prepend @createIcon 'cloud'
    .attr 'href', "#{@origin}/"
    .data 'url', '/'
  for seg, i in segs
    url = '/' + segs[0..i].map(encodeURIComponent).join('/') + '/'
    $ li = document.createElement 'li'
      .toggleClass 'active', i == segs.length - 1
      .appendTo '#path'
    $ document.createElement 'a'
      .appendTo li
      .text seg
      .prepend @createIcon 'folder'
      .attr 'href', "#{@origin}#{url}"
      .data 'url', url
  $ '#path li:not(:first-child)>a'
    .click (ev)=>
      ev.preventDefault()
      @jump_path $(ev.currentTarget).data 'url'

@refresh_filelist = (cb)=>
  cur_path = @m_path
  @upyun_readdir cur_path, (e, files)=>
    return cb e if e
    if @m_path == cur_path && JSON.stringify(@m_files) != JSON.stringify(files)
      $('#filelist tbody').empty()
      $('#filelist .preloader').css
        opacity: 0
      for file in @m_files = files
        $ tr = document.createElement 'tr'
          .appendTo '#filelist tbody'
        $ td = document.createElement 'td'
          .appendTo tr
        if file.isDirectory
          $ a = document.createElement 'a'
            .appendTo td
            .text file.filename
            .prepend @createIcon 'folder'
            .attr 'href', "#"
            .data 'url', file.url + '/'
            .click (ev)=> 
              ev.preventDefault()
              @jump_path $(ev.currentTarget).data('url')
        else
          $ td
            .text file.filename
            .prepend @createIcon 'file'
        $ document.createElement 'td'
          .appendTo tr
          .text if file.isDirectory then '' else @humanFileSize file.length
        $ document.createElement 'td'
          .appendTo tr
          .text moment(file.mtime).format 'LLL'
        $ td = document.createElement 'td'
          .appendTo tr
        if file.isDirectory
          $ document.createElement 'button'
            .appendTo td
            .attr title: '删除该目录'
            .addClass 'btn btn-danger btn-xs'
            .data 'url', file.url + '/'
            .data 'filename', file.filename
            .prepend @createIcon 'trash-o'
            .click (ev)=>
              filename = $(ev.currentTarget).data 'filename'
              url = $(ev.currentTarget).data 'url'
              @shortOperation "正在列出目录 #{filename} 下的所有文件", (doneFind, $btnCancelFind)=>
                $btnCancelFind.show().click => @upyun_find_abort()
                @upyun_find url, (e, files)=>
                  doneFind e
                  unless e
                    files_deleting = 0
                    async.eachSeries files, (file, doneEach)=>
                        files_deleting+= 1
                        @shortOperation "正在删除(#{files_deleting}/#{files.length}) #{file.filename}", (operationDone, $btnCancelDel)=>
                          $btnCancelDel.show().click @upyun_api 
                            method: "DELETE"
                            url: file.url
                            , (e)=>
                              operationDone e
                              doneEach e
                      , (e)=>
                        unless e
                          @shortOperation "正在删除 #{filename}", (operationDone, $btnCancelDel)=>
                            $btnCancelDel.show().click @upyun_api 
                              method: "DELETE"
                              url: url
                              , (e)=>
                                @m_changed_path = url.replace /[^\/]+\/$/, ''
                                operationDone e
        else
          $ document.createElement 'button'
            .appendTo td
            .attr title: '删除该文件'
            .addClass 'btn btn-danger btn-xs'
            .data 'url', file.url
            .data 'filename', file.filename
            .prepend @createIcon 'trash-o'
            .click (ev)=>
              url = $(ev.currentTarget).data('url')
              filename = $(ev.currentTarget).data('filename')
              @shortOperation "正在删除 #{filename}", (operationDone, $btnCancelDel)=>
                $btnCancelDel.show().click @upyun_api 
                  method: "DELETE"
                  url: url
                  , (e)=>
                    @m_changed_path = url.replace /\/[^\/]+$/, '/'
                    operationDone e
        if file.isDirectory
          $ document.createElement 'button'
            .appendTo td
            .attr title: '下载该目录'
            .addClass 'btn btn-info btn-xs'
            .prepend @createIcon 'download'
            .data 'url', file.url + '/'
            .data 'filename', file.filename
            .click (ev)=>
              @action_downloadFolder $(ev.currentTarget).data('filename'), $(ev.currentTarget).data('url')
          $ document.createElement 'button'
            .appendTo td
            .attr title: '向其他人分享该目录'
            .addClass 'btn btn-info btn-xs'
            .prepend @createIcon 'share'
            .data 'url', file.url + '/'
            .click (ev)=>
              url = $(ev.currentTarget).data 'url'
              @action_share url
        else
          $ document.createElement 'button'
            .appendTo td
            .attr title: '下载该文件'
            .addClass 'btn btn-info btn-xs'
            .prepend @createIcon 'download'
            .data 'url', file.url
            .data 'filename', file.filename
            .data 'length', file.length
            .click (ev)=>
              filename = $(ev.currentTarget).data 'filename'
              url = $(ev.currentTarget).data 'url'
              length = $(ev.currentTarget).data 'length'
              SaveAsFile filename, (savepath)=>
                @taskOperation "正在下载文件 #{filename} ..", (progressTransfer, doneTransfer, $btnCancelTransfer)=>
                  aborting = null
                  $btnCancelTransfer.click =>
                    aborting() if aborting?
                  _.defer =>
                    bytesWritten = 0
                    aborting = @upyun_api 
                      method: "GET"
                      url: url
                      pipeResponse: savepath
                      onData: (data)=>
                        bytesWritten += data.length
                        progressTransfer (Math.floor 100 * bytesWritten / length), "#{@humanFileSize bytesWritten} / #{@humanFileSize length}"
                      , (e, data)=>
                        doneTransfer e
                        unless e
                          msg = Messenger().post
                            message: "文件 #{filename} 下载完毕"
                            actions: 
                              ok:
                                label: '确定'
                                action: =>
                                  msg.hide()
                              open: 
                                label: "打开"
                                action: => 
                                  msg.hide()
                                  Electron.shell.openItem savepath
                              showItemInFolder: 
                                label: "打开目录"
                                action: => 
                                  msg.hide()
                                  Electron.shell.showItemInFolder savepath
          $ document.createElement 'button'
            .appendTo td
            .attr title: '在浏览器中访问该文件'
            .addClass 'btn btn-info btn-xs'
            .prepend @createIcon 'globe'
            .data 'url', "#{@origin}#{file.url}"
            .click (ev)=>
              url = $(ev.currentTarget).data 'url'
              Electron.shell.openExternal url
          $ document.createElement 'button'
            .appendTo td
            .attr title: '公共地址'
            .addClass 'btn btn-info btn-xs'
            .prepend @createIcon 'code'
            .data 'url', "#{@origin}#{file.url}"
            .data 'filename', file.filename
            .click (ev)=>
              filename = $(ev.currentTarget).data 'filename'
              url = $(ev.currentTarget).data 'url'
              @action_show_url "文件 #{filename} 的公共地址(URL)", url
          $ document.createElement 'button'
            .appendTo td
            .attr title: '用文本编辑器打开该文件'
            .addClass 'btn btn-info btn-xs'
            .prepend @createIcon 'edit'
            .data 'url', file.url
            .data 'filename', file.filename
            .click (ev)=>
              Open 'editor',
                username: @username
                password: @password
                bucket: @bucket
                editor_url: $(ev.currentTarget).data 'url'
                editor_filename: $(ev.currentTarget).data 'filename'
      $('#filelist tbody [title]')
        .tooltip
          placement: 'bottom'
          trigger: 'hover'
    cb null
@jump_editor = =>
  $ '#login, #filelist'
    .hide()
  $ '#editor'
    .show()
  window.document.title = @editor_filename
  @editor = Ace.edit $('#editor .editor')[0]
  $('#btnReloadEditor').click()


window.ondragover = window.ondrop = (ev)-> 
  ev.preventDefault()
  return false
$ =>
  @messengerTasks = $ document.createElement 'ul'
    .appendTo 'body'
    .messenger()
  forverCounter = 0
  async.forever (doneForever)=>
      if @m_active && !@shortOperationBusy
        forverCounter += 1
        if forverCounter == 20 || @m_changed_path == @m_path
          forverCounter = 0
          @m_changed_path = null
          return @refresh_filelist (e)=>
            if e
              msg = Messenger().post
                message: e.message
                type: 'error'
                actions: 
                  ok:
                    label: '确定'
                    action: =>
                      msg.hide()
              @jump_login()
            setTimeout (=>doneForever null), 100
      setTimeout (=>doneForever null), 100
    , (e)=>
      throw e


  $ '#inputBucket'
    .on 'input', (event)=>
      origin = $('#inputOrigin').val()
      return unless origin.endsWith('.b0.upaiyun.com')
      $('#inputOrigin').val("http://#{event.currentTarget.value}.b0.upaiyun.com")
  $ '#inputOrigin'
    .on 'change', (event)=>
      if !event.currentTarget.value.trim()
        $(event.currentTarget).val("http://#{$('#inputBucket').val()}.b0.upaiyun.com")
  $ '#btnAddFav'
    .click =>
      fav = $('#formLogin').serializeObject()
      fav.password = "MD5_" + MD5 fav.password unless fav.password.match /^MD5_/
      @m_favs["#{fav.username}@#{fav.bucket}"] = fav
      localStorage.favs = JSON.stringify @m_favs
      @refresh_favs()
  $ '#formLogin'
    .submit (ev)=>
      ev.preventDefault()
      @[k] = v for k, v of $(ev.currentTarget).serializeObject()
      @password = "MD5_" + MD5 @password unless @password.match /^MD5_/
      $ '#filelist tbody'
        .empty()
      @jump_filelist()
  $ window
    .on 'dragover', -> $('body').addClass 'drag_hover'
    .on 'dragleave', -> $('body').removeClass 'drag_hover'
    .on 'dragend', -> $('body').removeClass 'drag_hover'
    .on 'drop', (ev)=> 
      $('body').removeClass 'drag_hover'
      ev.preventDefault()
      for file in ev.originalEvent.dataTransfer.files
        @action_uploadFile file.path, file.name, "#{@m_path}#{encodeURIComponent file.name}"
  $ '#inputFilter'
    .keydown =>
      _.defer =>
        val = String $('#inputFilter').val()
        $ "#filelist tbody tr:contains(#{JSON.stringify val})"
          .removeClass 'filtered'
        $ "#filelist tbody tr:not(:contains(#{JSON.stringify val}))"
          .addClass 'filtered'
  $ '#btnDownloadFolder'
    .click (ev)=>
      ev.preventDefault()
      @action_downloadFolder null, @m_path
  $ '#btnUploadFiles'
    .click (ev)=>
      ev.preventDefault()
      SelectFiles (files)=>
        for filepath in files
          filename = Path.basename filepath
          @action_uploadFile filepath, filename, "#{@m_path}#{encodeURIComponent filename}"
  $ '#btnUploadFolder'
    .click (ev)=>
      ev.preventDefault()
      SelectFolder (dirpath)=>
        @action_uploadFile dirpath, Path.basename(dirpath), @m_path
  $ '#btnCreateFolder'
    .click (ev)=>
      ev.preventDefault()
      Prompt "请输入新目录的名称", (filename)=>
        @shortOperation "正在新建目录 #{filename} ...", (doneCreating, $btnCancelCreateing)=>
          cur_path = @m_path
          $btnCancelCreateing.click @upyun_api
            url: "#{cur_path}#{filename}"
            method: "POST"
            headers: 
              'Folder': 'true'
            , (e, data)=>
              doneCreating e
              @m_changed_path = cur_path
  $ '#btnCreateFile'
    .click (ev)=>
      ev.preventDefault()
      Prompt "请输入新文件的文件名", (filename)=>
        Open 'editor',
          username: @username
          password: @password
          bucket: @bucket
          editor_url: "#{@m_path}#{filename}"
          editor_filename: filename
  $ '#btnReloadEditor'
    .click (ev)=>
      ev.preventDefault()
      @shortOperation "正在加载文件 #{@editor_filename} ...", (doneReloading, $btnCancelReloading)=>
        $btnCancelReloading.click @upyun_api 
          url: @editor_url
          method: 'GET'
          , (e, data)=>
            if e
              data = '' 
            else
              data = data.toString 'utf8'
            doneReloading null
            unless e
              @editor.setValue data
  $ '#btnShareFolder'
    .click (ev)=>
      @action_share @m_path
  $ '#btnSaveEditor'
    .click (ev)=>
      ev.preventDefault()
      @shortOperation "正在保存文件 #{@editor_filename} ...", (doneSaving, $btnCancelSaving)=>
        $btnCancelSaving.click @upyun_api 
            url: @editor_url
            method: 'PUT'
            data: new Buffer @editor.getValue(), 'utf8'
          , (e)=>
            doneSaving e
            unless e
              msg = Messenger().post
                message: "成功保存文件 #{@editor_filename}"
                actions: 
                  ok:
                    label: '确定'
                    action: =>
                      msg.hide()
  $ '#btnLogout'
    .click (ev)=>
      ev.preventDefault()
      @jump_login()
  $ '#btnIssues'
    .click (ev)=>
      ev.preventDefault()
      Electron.shell.openExternal "https://github.com/layerssss/manager-for-upyun/issues"
  $ '[title]'
    .tooltip
      placement: 'bottom'
      trigger: 'hover'
  
  window.Init = (action, params) =>
    for key, value of params
      @[key] = value
    @["jump_#{action}"]()
        


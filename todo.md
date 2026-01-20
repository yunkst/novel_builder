# 沉浸体验功能：

在阅读的时候，的右上角增加一个选项：沉浸体验 ， 点击后出现一个
  对话框，要求用户输入沉浸体验的要求和参与体验的角色列表,还有用户自己扮演的角色。确定提交之后，进入到一个沉浸式体验的初始化准备页面，发送信息给 阻塞 dify 请求生成剧本，
cmd=生成剧本 ,
chapter_content=[本章内容] ,
  roles=[刚才选择的角色]，
  user_input=[用户的要求] ,
  user_choice_role=[用户选择的角色名，这个角色必须在roles中]
 在初始化页面中，等dify返回数据并展示以下内容：
 play: 剧本
 role_strategy： 角色策略列表
 用户可以提出修改意见，然后让AI重新生成，在发给 dify 的参数增加
 play 和 role_strategy 就可以。
 等待生成的过程需要有动画提示用户正在生成中


3. 进入聊天室，发送信息给dify 包含 剧本，角色信息，聊天历史，dify 返回 speaker content 
如果 speaker 是 roles ，那么就展示一条角色信息。
如果 speaker 是 system，则展示一条旁白信息，用来描写
如果 speaker 是 用户，则展示 recomment-content 方便用户快速选择，用户也可以自定义

4. 生图功能点击后，后发送给 backend 进行插图创作， 在聊天室插入一条插图组件，可以删除等操作。
5. chatroom 可以随时退出，可以在任意时候返回 chatroom 续写。可以删除 chatroom 信息


# 听书功能

可以 通过 服务端合成音频，实现一个听书播放器
底层用 comfyui 运行 vibevoice 生成音频

# 创建指定角色
输入角色名+别名，在全文搜索相关章节，并把章节内容组合后，发送给dify ，生成角色卡片。


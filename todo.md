# 沉浸体验功能：

1. 在任意段落可以进入，在进入之前，可以选择参与角色，本章内容作为上下文，并在进入段落那边做好一个标记。
2. 把本章内容发送给 dify 生成沉浸体验上下文信息，要求生成环境，剧本
3. 进入聊天室，发送信息给dify 包含 剧本，角色信息，聊天历史，dify 返回 speaker content recomment-content.
如果speaker 是 roles ，那么就展示一条角色信息。
如果 speaker 是旁白，则展示一条旁白信息，并提供生图按钮
如果 speaker 是用户，则展示 recomment-content 方便用户快速选择，用户也可以自定义

4. 生图功能点击后，后发送给 backend 进行插图创作， 在聊天室插入一条插图组件，可以删除等操作。
5. chatroom 可以随时退出，可以在任意时候返回 chatroom 续写。可以删除 chatroom 信息
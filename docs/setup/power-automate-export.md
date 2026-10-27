# Power Automate 导出流程配置说明（#83）

给**设置者**（帮目标用户安装 DailyNote 的人）看。照着做完，她的 Outlook 收件箱每天 07:00 和 16:00 会自动导出一次，以信封格式写到她的 OneDrive，再同步到她的电脑上，由 DailyNote 导入。

设计依据见 spec 0002 的"Power Automate 流程"和"导出文件格式"。用词见 `GLOSSARY.md`。下文的"她"指目标用户。文中的邮箱和名字都是虚构的。

一共要建两个流程：

| 流程 | 触发方式 | 取多少封 | 用途 |
|---|---|---|---|
| DailyNote 邮件导出 | 每天 07:00 和 16:00（Eastern Time） | 最近 200 封 | 日常使用 |
| DailyNote 邮件补读 | 手动 | 最近 1000 封 | 断开很久之后补上漏掉的邮件 |

## 开始之前：必须用她自己的账号

整个流程里的每一样东西都必须属于**她的**学校账号：

- 在 <https://make.powerautomate.com> 登录时，用的是**她的**学校账号，密码由她本人输入。
- 流程里的 Outlook 连接和 OneDrive 连接是**她的**账号创建的。**不要**用你（开发者或设置者）自己的连接，也不要选择列表里任何不是她的连接。
- 不要把流程共享给其他人，也不要添加共同所有者。共同所有者可以使用流程里的连接，也就能读到她的邮件。

建好以后可以检查：左侧菜单 **更多 → 连接（Connections）**，列表里只有她自己邮箱地址的 Office 365 Outlook 和 OneDrive for Business 连接。

## 界面上的名字

Power Automate 的界面可能是中文，也可能是英文。下文写成 **中文（English）**。界面版本不同时，按钮的位置可能会有差别，但名字是一样的。

**步骤一定要按下文改名**。表达式是按步骤名找到上一步结果的；默认的步骤名会随界面语言变化（例如"获取电子邮件 (V3)"），容易填错。下文所有表达式都只引用改过的英文名：`GetEmails` 和 `Envelope`。改名方法：点开这个步骤，点标题，输入新名字。

## 流程一：DailyNote 邮件导出（定时）

### 1. 新建流程，设置定时触发

1. 左侧菜单 **创建（Create）→ 计划的云端流（Scheduled cloud flow）**。
2. 流名称（Flow name）：`DailyNote 邮件导出`。
3. 开始时间随便填今天，重复周期选 **每 1 天（Repeat every 1 Day）**，点 **创建（Create）**。
4. 点开触发器 **重复（Recurrence）**，按下表填：

| 字段 | 填写 |
|---|---|
| 间隔（Interval） | `1` |
| 频率（Frequency） | 天（Day） |
| 时区（Time zone） | `(UTC-05:00) 东部时间(美国和加拿大)`（`(UTC-05:00) Eastern Time (US & Canada)`） |
| 在这些小时（At these hours） | `7` 和 `16` |
| 在这些分钟（At these minutes） | `0` |

"时区"和"在这些小时"可能在 **显示所有（Show all）** 或 **高级参数（Advanced parameters）** 里。选了 Eastern Time 以后，夏令时会自动处理。

### 2. 初始化变量 mailbox

1. 点 **+ → 添加操作（Add an action）**，搜索 `初始化变量`（`Initialize variable`）。
2. 按下表填：

| 字段 | 填写 |
|---|---|
| 名称（Name） | `mailbox` |
| 类型（Type） | 字符串（String） |
| 值（Value） | 她的学校邮箱地址，例如 `student@example.edu` |

这个地址会写进每个导出文件，DailyNote 按它区分邮箱、去重。要填她的**完整**邮箱地址，不要有空格。

### 3. 获取电子邮件

1. 添加操作，搜索 `获取电子邮件 (V3)`（`Get emails (V3)`），选 **Office 365 Outlook** 下面的那个。注意是 **(V3)**，不要选旧版本。
2. 第一次使用时会要求登录创建连接：确认登录的是**她的**账号。
3. 把这个步骤改名为 `GetEmails`。
4. 按下表填（没列出的字段保持默认，留空）：

| 字段 | 填写 |
|---|---|
| 文件夹（Folder） | 收件箱（Inbox） |
| 前 / 顶部（Top） | `200` |
| 仅获取未读邮件（Fetch Only Unread Messages） | 否（No） |
| 包括附件（Include Attachments） | 否（No） |
| 重要性（Importance） | 任意（Any） |
| 仅限有附件（Only with Attachments） | 否（No） |
| 搜索查询（Search Query）、收件人（To）、发件人（From）、主题筛选（Subject Filter）等 | 留空 |

### 4. 撰写信封

1. 添加操作，搜索 `撰写`（`Compose`），选 **数据操作（Data Operation）** 下面的那个。
2. 改名为 `Envelope`。
3. 点 **输入（Inputs）** 框，选 **插入表达式（Insert expression，fx 图标）**，把下面的表达式**原样**粘贴进去，点 **添加（Add）**：

```text
addProperty(addProperty(addProperty(json('{"format":"dailynote-mail-export","version":1}'), 'mailbox', variables('mailbox')), 'exportedAt', utcNow()), 'messages', body('GetEmails')?['value'])
```

结果是这样一个 JSON（就是信封格式）：

```json
{
  "format": "dailynote-mail-export",
  "version": 1,
  "mailbox": "student@example.edu",
  "exportedAt": "2026-10-27T11:00:03.1234567Z",
  "messages": [ ...获取电子邮件 (V3) 返回的邮件... ]
}
```

**不要**把这个 JSON 直接打进"输入"框，再把邮件列表当作动态内容插进去。那样插进去的邮件列表可能会变成一段字符串，DailyNote 会把整个文件当作格式错误。

### 5. 写到 OneDrive

1. 添加操作，搜索 `创建文件`（`Create file`），选 **OneDrive for Business** 下面的那个。不要选个人版的 OneDrive，也不要选 SharePoint。
2. 第一次使用时会要求登录创建连接：确认登录的是**她的**账号。
3. 按下表填：

| 字段 | 填写 |
|---|---|
| 文件夹路径（Folder Path） | 点文件夹图标，选她 OneDrive 里的一个**专用**文件夹，例如 `/DailyNote 邮件`（没有的话先在 OneDrive 网页里建好）。这个文件夹只放导出文件 |
| 文件名（File Name） | 用 **插入表达式**，粘贴下面的表达式 |
| 文件内容（File Content） | 用 **插入表达式**，粘贴 `outputs('Envelope')` |

文件名表达式：

```text
concat('mail-', formatDateTime(utcNow(), 'yyyyMMdd-HHmmss'), '-', workflow()?['run']?['name'], '.json')
```

生成的文件名类似 `mail-20261027-110003-08584...CU31.json`：前面是 UTC 时间（精确到秒），后面是这次运行的编号，所以永远不会覆盖还没导入的文件。DailyNote 只读 `mail-*.json`，**不要**改掉开头的 `mail-` 和结尾的 `.json`。

### 6. 保存

点 **保存（Save）**。流程从上到下应该是：

```text
重复（Recurrence）            每天 07:00、16:00，Eastern Time
→ 初始化变量（mailbox）        她的邮箱地址
→ GetEmails                   收件箱，Top 200，不包括附件
→ Envelope                    信封格式
→ 创建文件                     /DailyNote 邮件/mail-<时间>-<运行编号>.json
```

导出文件不需要手动清理：DailyNote 会删除已经导入、超过 14 天的文件。

## 流程二：DailyNote 邮件补读（手动）

步骤和流程一完全一样，只有两处不同：

1. 第 1 步改成 **创建 → 即时云端流（Instant cloud flow）**，名称 `DailyNote 邮件补读`，触发器选 **手动触发流（Manually trigger a flow）**。没有定时设置。
2. 第 3 步 `GetEmails` 的 **Top** 填 `1000`（这是这个操作允许的最大值）。

其他步骤（变量、`GetEmails` 和 `Envelope` 的改名、两个表达式、同一个 OneDrive 文件夹）照抄。

**什么时候用**：DailyNote 的状态栏提示"可能有遗漏，请让设置者手动补读"时，或者流程停了很久（例如连接过期了好几天）之后。打开这个流程，点 **运行（Run）** 即可。和之前的文件重叠的邮件，DailyNote 会自动去重。

## 流程包

现在**没有**提供流程包，只用上面的图文说明。

如果以后要做：在一个**只有虚构数据**的测试账号里，按上面的步骤建好流程，然后用 **导出 → 包 (.zip)（Export → Package (.zip)）** 导出。导入到她的账号时，在"导入设置"里把每个连接都改成 **在导入期间选择（Select during import）**，然后选择或新建**她自己的**连接，不要选导入包里带的连接。流程包放在仓库里，不放进 DailyNote 的安装包。spec 0002 里还没验证她的学校租户是否允许导入流程包，导入失败时就按图文说明手动建。

## 验收：建好以后检查一遍

按顺序做，每一条都要成立。任何一条不成立，都先停下来，把现象记下来，回到 spec 0002 修改流程设计（见 spec 的"待验证事项"）。

### A. 手动运行一次能生成文件（M-38）

1. 打开流程 **DailyNote 邮件导出**，点 **测试（Test）→ 手动（Manually）→ 测试（Test）→ 运行流（Run flow）**。
2. 等运行结束，每个步骤都显示绿色的对勾。
3. 在 OneDrive 网页里打开 `/DailyNote 邮件`，出现了一个 `mail-....json` 文件。
4. 下载这个文件，用记事本打开。开头是 `{"format":"dailynote-mail-export","version":1,"mailbox":"...`，`mailbox` 是她的邮箱地址，后面的 `"messages":[` 后面紧跟着 `{`，**不是** `"`（如果是 `"`，说明邮件列表被写成了字符串，回去检查第 4 步）。
5. 在她的电脑上，打开文件资源管理器里的 OneDrive 文件夹，`DailyNote 邮件` 里也出现了这个文件。建议右键这个文件夹，选 **始终保留在此设备上（Always keep on this device）**，这样 DailyNote 读文件时不用等下载。

### B. 定时流程能建立并按时运行（M-39 第 1 点）

1. 保存流程时没有出现"许可证"或"策略"相关的报错，流程状态是 **开启（On）**。
2. 等到下一个 07:00 或 16:00（Eastern Time）之后，打开流程的 **运行历史记录（Run history）**，出现一条不是你手动触发的运行，状态是 **成功（Succeeded）**。
3. OneDrive 里又多了一个新文件。

### C. Top 200 真的返回 200 封（M-39 第 2 点）

只有她的收件箱里**超过 200 封**邮件时才能检查。

1. 在运行历史记录里打开刚才成功的那次运行，点开 `GetEmails` 步骤，点 **显示原始输出（Show raw outputs）**。
2. `value` 里的邮件数应该是 200。数起来不方便的话，可以临时在 `GetEmails` 后面加一个 **撰写（Compose）**，输入用表达式 `length(body('GetEmails')?['value'])`，运行一次看它的输出是不是 `200`。检查完把这个临时步骤删掉，再保存。

### D. 最新的邮件排在前面（M-39 第 3 点）

1. 在同一个原始输出里，看 `value` 里第一封邮件的 `receivedDateTime` 和最后一封的 `receivedDateTime`。
2. 第一封应该是收件箱里**最新**的邮件（和她在 Outlook 里看到的最上面一封对得上），最后一封是最早的。

### E. 连接都是她的

1. 左侧菜单 **更多 → 连接（Connections）**：Office 365 Outlook 和 OneDrive for Business 的连接显示的都是她的邮箱地址。
2. 流程的详细信息页里，**所有者（Owners）** 只有她一个人。

### 顺便确认

她用的是**经典版**还是**新版** Outlook（spec 0002"待验证事项"的最后一条），记下来就行，不影响这个流程。

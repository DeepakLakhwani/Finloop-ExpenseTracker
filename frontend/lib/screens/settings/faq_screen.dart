import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  // Self-contained localized FAQs for all 15 supported languages
  static const Map<String, List<Map<String, String>>> _faqData = {
    'en': [
      {
        'q': "What is FinLoop?",
        'a': "FinLoop is a premium, secure, and modern personal finance tracker. It helps you manage transactions, split group expenses, set budgets, and view spending analytics."
      },
      {
        'q': "Where is my data stored?",
        'a': "Your data is stored securely in Firebase Cloud Firestore. This allows real-time synchronization across all your logged-in devices."
      },
      {
        'q': "Are my passcode and biometrics safe?",
        'a': "Yes. FinLoop uses your device's native operating system security for passcodes and biometrics. We never access, store, or transmit your raw biometrics."
      },
      {
        'q': "How do I export my data?",
        'a': "You can export transaction statements to PDF from the Transactions screen, or backup all records to an Excel spreadsheet from Settings -> Backup."
      },
      {
        'q': "How do I contact support?",
        'a': "Go to Settings -> Feedback to send a message directly to our support team. You can also attach a screenshot of the issue."
      }
    ],
    'es': [
      {
        'q': "¿Qué es FinLoop?",
        'a': "FinLoop es un rastreador de finanzas personales premium, seguro y moderno. Te ayuda a administrar transacciones, dividir gastos grupales, establecer presupuestos y ver análisis de gastos."
      },
      {
        'q': "¿Dónde se almacenan mis datos?",
        'a': "Tus datos se almacenan de forma segura en Firebase Cloud Firestore. Esto permite la sincronización en tiempo real en todos tus dispositivos conectados."
      },
      {
        'q': "¿Están seguros mi contraseña y mis datos biométricos?",
        'a': "Sí. FinLoop utiliza la seguridad nativa del sistema operativo de tu dispositivo para contraseñas y datos biométricos. Nunca accedemos, almacenamos ni transmitimos tus datos biométricos originales."
      },
      {
        'q': "¿Cómo exporto mis datos?",
        'a': "Puedes exportar extractos de transacciones a PDF desde la pantalla de Transacciones, o hacer una copia de seguridad de todos los registros en una hoja de cálculo de Excel desde Ajustes -> Copia de seguridad."
      },
      {
        'q': "¿Cómo me comunico con soporte?",
        'a': "Ve a Ajustes -> Comentarios para enviar un mensaje directamente a nuestro equipo de soporte. También puedes adjuntar una captura de pantalla del problema."
      }
    ],
    'pt': [
      {
        'q': "O que é o FinLoop?",
        'a': "O FinLoop é um gerenciador de finanças pessoais premium, seguro e moderno. Ele ajuda você a gerenciar transações, dividir despesas de grupo, definir orçamentos e visualizar análises de gastos."
      },
      {
        'q': "Onde meus dados são armazenados?",
        'a': "Seus dados são armazenados com segurança no Firebase Cloud Firestore. Isso permite a sincronização em tempo real em todos os seus dispositivos conectados."
      },
      {
        'q': "Minha senha e dados biométricos estão seguros?",
        'a': "Sim. O FinLoop usa a segurança nativa do sistema operacional do seu dispositivo para senhas e biometria. Nunca acessamos, armazenamos ou transmitimos seus dados biométricos brutos."
      },
      {
        'q': "Como exportar meus dados?",
        'a': "Você pode exportar extratos de transações para PDF na tela de Transações ou fazer backup de todos os registros em uma planilha Excel em Configurações -> Backup."
      },
      {
        'q': "Como entrar em contato com o suporte?",
        'a': "Acesse Configurações -> Feedback para enviar uma mensagem diretamente à nossa equipe de suporte. Você também pode anexar uma captura de tela do problema."
      }
    ],
    'fr': [
      {
        'q': "Qu'est-ce que FinLoop ?",
        'a': "FinLoop est un tracker de finances personnelles premium, sécurisé et moderne. Il vous aide à gérer les transactions, diviser les dépenses de groupe, définir des budgets et analyser vos dépenses."
      },
      {
        'q': "Où mes données sont-elles stockées ?",
        'a': "Vos données sont stockées en toute sécurité dans Firebase Cloud Firestore. Cela permet une synchronisation en temps réel sur tous vos appareils connectés."
      },
      {
        'q': "Mon code d'accès et mes données biométriques sont-ils sécurisés ?",
        'a': "Oui. FinLoop utilise la sécurité native du système d'exploitation de votre appareil pour les codes d'accès et la biométrie. Nous n'accédons, ne stockons ni ne transmettons jamais vos données biométriques brutes."
      },
      {
        'q': "Comment exporter mes données ?",
        'a': "Vous pouvez exporter des relevés de transactions au format PDF depuis l'écran Transactions, ou sauvegarder tous les enregistrements dans un fichier Excel depuis Paramètres -> Sauvegarde."
      },
      {
        'q': "Comment contacter le support ?",
        'a': "Allez dans Paramètres -> Commentaires pour envoyer un message directement à notre équipe de support. Vous pouvez également joindre une capture d'écran du problème."
      }
    ],
    'de': [
      {
        'q': "Was ist FinLoop?",
        'a': "FinLoop ist ein erstklassiger, sicherer und moderner persönlicher Finanz-Tracker. Er hilft Ihnen, Transaktionen zu verwalten, Gruppenkosten aufzuteilen, Budgets festzulegen und Ausgabenanalysen anzuzeigen."
      },
      {
        'q': "Wo werden meine Daten gespeichert?",
        'a': "Ihre Daten werden sicher in Firebase Cloud Firestore gespeichert. Dies ermöglicht eine Echtzeit-Synchronisierung auf all Ihren angemeldeten Geräten."
      },
      {
        'q': "Sind mein Passcode und meine biometrischen Daten sicher?",
        'a': "Ja. FinLoop nutzt die native Sicherheit des Betriebssystems Ihres Geräts für Passcodes und Biometrie. Wir greifen niemals auf Ihre biometrischen Rohdaten zu, speichern oder übertragen sie nicht."
      },
      {
        'q': "Wie exportiere ich meine Daten?",
        'a': "Sie können Transaktionsberichte über den Transaktionsbildschirm als PDF exportieren oder alle Datensätze über Einstellungen -> Backup in eine Excel-Tabelle exportieren."
      },
      {
        'q': "Wie kontaktiere ich den Support?",
        'a': "Gehen Sie zu Einstellungen -> Feedback, um eine Nachricht direkt an unser Support-Team zu senden. Sie können auch einen Screenshot des Problems anhängen."
      }
    ],
    'hi': [
      {
        'q': "FinLoop क्या है?",
        'a': "FinLoop एक प्रीमियम, सुरक्षित और आधुनिक व्यक्तिगत वित्त ट्रैकर है। यह आपको लेनदेन प्रबंधित करने, समूह के खर्चों को विभाजित करने, बजट निर्धारित करने और खर्च विश्लेषण देखने में मदद करता है।"
      },
      {
        'q': "मेरा डेटा कहां संग्रहीत होता है?",
        'a': "आपका डेटा Firebase Cloud Firestore में सुरक्षित रूप से संग्रहीत है। यह आपके सभी लॉग-इन डिवाइसों में रीयल-टाइम सिंक्रनाइज़ेशन की अनुमति देता है।"
      },
      {
        'q': "क्या मेरा पासकोड और बायोमेट्रिक्स सुरक्षित हैं?",
        'a': "हाँ। FinLoop पासकोड और बायोमेट्रिक्स के लिए आपके डिवाइस की मूल ऑपरेटिंग सिस्टम सुरक्षा का उपयोग करता है। हम कभी भी आपके बायोमेट्रिक्स डेटा को एक्सेस, स्टोर या ट्रांसमिट नहीं करते हैं।"
      },
      {
        'q': "मैं अपना डेटा कैसे निर्यात करूं?",
        'a': "आप लेनदेन स्क्रीन से पीडीएफ में लेनदेन विवरण निर्यात कर सकते हैं, या सेटिंग्स -> बैकअप से सभी रिकॉर्ड्स को एक्सेल स्प्रेडशीट में बैकअप कर सकते हैं।"
      },
      {
        'q': "मैं समर्थन से कैसे संपर्क करूं?",
        'a': "हमारी सहायता टीम को सीधे संदेश भेजने के लिए सेटिंग्स -> फीडबैक पर जाएं। आप समस्या का स्क्रीनशॉट भी संलग्न कर सकते हैं।"
      }
    ],
    'gu': [
      {
        'q': "FinLoop શું છે?",
        'a': "FinLoop એ પ્રીમિયમ, સુરક્ષિત અને આધુનિક વ્યક્તિગત નાણાકીય ટ્રેકર છે. તે તમને વ્યવહારોનું સંચાલન કરવા, જૂથ ખર્ચો વિભાજિત કરવા, બજેટ સેટ કરવા અને ખર્ચ વિશ્લેષણ જોવામાં મદદ કરે છે."
      },
      {
        'q': "મારો ડેટા ક્યાં સંગ્રહિત થાય છે?",
        'a': "તમારો ડેટા Firebase Cloud Firestore માં સુરક્ષિત રીતે સંગ્રહિત છે. આ તમારા બધા લોગ-ઇન ઉપકરણો પર રીઅલ-ટાઇમ સિંક્રનાઇઝેશનની મંજૂરી આપે છે."
      },
      {
        'q': "શું મારો પાસકોડ અને બાયોમેટ્રિક્સ સુરક્ષિત છે?",
        'a': "હા. FinLoop પાસકોડ અને બાયોમેટ્રિક્સ માટે તમારા ઉપકરણની મૂળ ઓપરેટિંગ સિસ્ટમ સુરક્ષાનો ઉપયોગ કરે છે. અમે ક્યારેય તમારા બાયોમેટ્રિક્સ ડેટાને એક્સેસ, સ્ટોર કે ટ્રાન્સમિટ કરતા નથી."
      },
      {
        'q': "હું મારો ડેટา કેવી રીતે નિકાસ કરું?",
        'a': "તમે ટ્રાન્ઝેક્શન સ્ક્રીન પરથી પીડીએફમાં ટ્રાન્ઝેક્શન સ્ટેટમેન્ટ નિકાસ કરી શકો છો, અથવા સેટિંગ્સ -> બેકઅપ પરથી તમામ રેકોર્ડ્સને એક્સેલ સ્પ્રેડશીટમાં નિકાસ કરી શકો છો."
      },
      {
        'q': "અમે સપોર્ટનો સંપર્ક કેવી રીતે કરીએ?",
        'a': "અમારી સપોર્ટ ટીમને સીધો સંદેશ મોકલવા માટે સેટિંગ્સ -> પ્રતિસાદ પર જાઓ. તમે સમસ્યાનો સ્ક્રીનશોટ પણ જોડી શકો છો."
      }
    ],
    'ja': [
      {
        'q': "FinLoopとは何ですか？",
        'a': "FinLoopは、プレミアムで安全かつモダンな個人財務管理アプリです。取引の管理、グループでの割り勘、予算の設定、支出分析の表示をサポートします。"
      },
      {
        'q': "データはどこに保存されますか？",
        'a': "データはFirebase Cloud Firestoreに安全に保存されます。これにより、ログインしているすべてのデバイス間でリアルタイムに同期されます。"
      },
      {
        'q': "パスコードや生体認証は安全ですか？",
        'a': "はい。FinLoopはパスコードと生体認証にデバイス固有のオペレーティングシステムセキュリティを使用します。生体認証データを収集、保存、送信することはありません。"
      },
      {
        'q': "データをエクスポートするにはどうすればよいですか？",
        'a': "取引画面からPDFとしてエクスポートするか、設定 -> バックアップからすべてのデータをExcelスプレッドシートにエクスポートできます。"
      },
      {
        'q': "サポートに連絡するにはどうすればよいですか？",
        'a': "設定 -> フィードバックに移動して、サポートチームに直接メッセージを送信してください。問題のスクリーンショットを添付することもできます。"
      }
    ],
    'zh': [
      {
        'q': "什么是 FinLoop？",
        'a': "FinLoop 是一款高端、安全且现代的个人财务管理应用。它可帮助您管理交易、分摊群组费用、设定预算并查看支出分析。"
      },
      {
        'q': "我的数据存储在哪里？",
        'a': "您的数据安全地存储在 Firebase Cloud Firestore 中。这使您所有已登录的设备能够进行实时同步。"
      },
      {
        'q': "我的密码和生物识别数据安全吗？",
        'a': "是地。FinLoop 使用您设备的原生操作系统安全功能来保护密码和生物识别。我们绝不会访问、存储或传输您的原始生物识别数据。"
      },
      {
        'q': "如何导出我的数据？",
        'a': "您可以从“交易”屏幕将交易明细导出为 PDF，或者通过“设置” -> “备份”将所有记录备份到 Excel 电子表格中。"
      },
      {
        'q': "如何联系客户支持？",
        'a': "前往“设置” -> “反馈”直接向我们的支持团队发送消息。您也可以附上问题的屏幕截图。"
      }
    ],
    'ko': [
      {
        'q': "FinLoop은 무엇인가요?",
        'a': "FinLoop은 프리미엄급의 안전하고 현대적인 개인 금융 관리 앱입니다. 거래 관리, 그룹 비용 분할, 예산 설정, 지출 분석 조회를 지원합니다."
      },
      {
        'q': "내 데이터는 어디에 저장되나요?",
        'a': "귀하의 데이터는 Firebase Cloud Firestore에 안전하게 저장됩니다. 이를 통해 로그인된 모든 기기 간에 실시간 동기화가 가능합니다."
      },
      {
        'q': "비밀번호와 생체인식 정보는 안전한가요?",
        'a': "네. FinLoop은 비밀번호와 생체인식을 위해 기기 자체의 기본 운영체제 보안을 사용합니다. 당사는 귀하의 민감한 생체정보에 접근하거나 저장, 전송하지 않습니다."
      },
      {
        'q': "データを어떻게 내보내나요?",
        'a': "거래 화면에서 PDF로 내보내거나, 설정 -> 백업 메뉴를 통해 모든 내역을 Excel 스프레드시트로 내보낼 수 있습니다."
      },
      {
        'q': "지원팀에 어떻게 연락하나요?",
        'a': "설정 -> 피드백으로 이동하여 지원팀에 직접 메시지를 보내실 수 있습니다. 문제 화면의 스크린샷을 첨부할 수도 있습니다."
      }
    ],
    'ar': [
      {
        'q': "ما هو FinLoop؟",
        'a': "هو متتبع مالي شخصي متميز وآمن وعصري. يساعدك على إدارة المعاملات، وتقسيم مصاريف المجموعة، وتعيين الميزانيات، وعرض تحليلات الإنفاق."
      },
      {
        'q': "أين يتم تخزين بياناتي المادية؟",
        'a': "يتم تخزين بياناتك بشكل آمن في قاعدة بيانات Firebase Cloud Firestore. هذا يتيح المزامنة الفورية بين جميع أجهزتك النشطة."
      },
      {
        'q': "هل رمز المرور والبيانات البيومترية آمنة؟",
        'a': "نعم. يستخدم التطبيق أمان نظام التشغيل الأصلي لجهازك لحماية الرموز والبصمات. نحن لا نصل إلى بياناتك البيومترية ولا نخزنها أبداً."
      },
      {
        'q': "كيف يمكنني تصدير بياناتي؟",
        'a': "يمكنني تصدير كشوف المعاملات إلى ملف PDF من شاشة المعاملات، أو الاحتفاظ بنسخة احتياطية من كل السجلات في جدول بيانات Excel من الإعدادات -> النسخ الاحتياطي."
      },
      {
        'q': "كيف أتصل بالدعم الفني؟",
        'a': "انتقل إلى الإعدادات -> الملاحظات لإرسال رسالة مباشرة إلى فريق الدعم. يمكنك أيضاً إرفاق لقطة شاشة للمشكلة."
      }
    ],
    'ru': [
      {
        'q': "Что такое FinLoop?",
        'a': "FinLoop — это премиальный, безопасный и современный инструмент для отслеживания личных финансов. Он помогает управлять транзакциями, разделять групповые расходы, устанавливать бюджеты и анализировать траты."
      },
      {
        'q': "Где хранятся мои финансовые данные?",
        'a': "Ваши данные надежно хранятся в Firebase Cloud Firestore. Это обеспечивает синхронизацию в реальном времени на всех ваших устройствах."
      },
      {
        'q': "Безопасны ли мой пароль и биометрия?",
        'a': "Да. FinLoop использует встроенную безопасность операционной системы вашего устройства для паролей и биометрии. Мы никогда не получаем доступ, не храним и не передаем ваши биометрические данные."
      },
      {
        'q': "Как экспортировать свои транзакции?",
        'a': "Вы можете экспортировать выписку в PDF на экране транзакций или сделать резервную копию всех записей в таблицу Excel через Настройки -> Резервное копирование."
      },
      {
        'q': "Как связаться со службой поддержки?",
        'a': "Перейдите в Настройки -> Обратная связь, чтобы отправить сообщение нашей команде поддержки. Вы также можете прикрепить снимок экрана с проблемой."
      }
    ],
    'th': [
      {
        'q': "FinLoop คืออะไร?",
        'a': "FinLoop เป็นแอปบันทึกรายรับรายจ่ายส่วนบุคคลระดับพรีเมียม ปลอดภัย และทันสมัย ช่วยให้คุณจัดการธุรกรรม แบ่งปันค่าใช้จ่ายกลุ่ม ตั้งงบประมาณ และดูการวิเคราะห์การใช้จ่ายได้ง่ายขึ้น"
      },
      {
        'q': "ข้อมูลทางการเงินของฉันถูกจัดเก็บไว้ที่ไหน?",
        'a': "ข้อมูลของคุณจะถูกเก็บไว้อย่างปลอดภัยใน Firebase Cloud Firestore ซึ่งช่วยให้สามารถซิงค์ข้อมูลแบบเรียลไทม์ในทุกอุปกรณ์ที่คุณเข้าสู่ระบบ"
      },
      {
        'q': "รหัสผ่านและระบบสแกนลายนิ้วมือ/ใบหน้าของฉันปลอดภัยหรือไม่?",
        'a': "ปลอดภัยอย่างยิ่ง FinLoop ใช้ระบบรักษาความปลอดภัยของระบบปฏิบัติการในอุปกรณ์ของคุณโดยตรง เราไม่เคยเข้าถึง จัดเก็บ หรือส่งข้อมูลชีวมาตรดิบของคุณ"
      },
      {
        'q': "ฉันจะส่งออกข้อมูลธุรกรรมได้อย่างไร?",
        'a': "คุณสามารถส่งออกรายการธุรกรรมเป็น PDF ได้จากหน้าจอธุรกรรม หรือสำรองข้อมูลทั้งหมดเป็นสเปรดชีต Excel จากเมนู การตั้งค่า -> สำรองข้อมูล"
      },
      {
        'q': "ฉันจะติดต่อฝ่ายสนับสนุนได้อย่างไร?",
        'a': "ไปที่ การตั้งค่า -> ข้อเสนอแนะ เพื่อส่งข้อความถึงทีมสนับสนุนของเราโดยตรง และคุณสามารถแนบภาพหน้าจอของปัญหามาด้วยได้"
      }
    ],
    'ms': [
      {
        'q': "Apakah itu FinLoop?",
        'a': "FinLoop ialah penjejak kewangan peribadi premium, selamat dan moden. Ia membantu anda mengurus transaksi, membahagi perbelanjaan kumpulan, menetapkan belanjawan dan menganalisis perbelanjaan."
      },
      {
        'q': "Di manakah data saya disimpan?",
        'a': "Data saya disimpan dengan selamat dalam Firebase Cloud Firestore. Ini membolehkan penyelarasan masa nyata merentas semua peranti anda yang log masuk."
      },
      {
        'q': "Adakah kod laluan dan biometrik saya selamat?",
        'a': "Ya. FinLoop menggunakan keselamatan sistem operasi asal peranti anda untuk kod laluan dan biometrik. Kami tidak pernah mengakses, menyimpan atau menghantar data biometrik mentah anda."
      },
      {
        'q': "Bagaimanakah cara saya mengeksport data saya?",
        'a': "Anda boleh mengeksport penyata transaksi ke PDF dari skrin Transaksi, atau menyandar semua rekod ke hamparan Excel dari Tetapan -> Sandaran."
      },
      {
        'q': "Bagaimanakah cara saya menghubungi sokongan?",
        'a': "Pergi ke Tetapan -> Maklum Balas untuk menghantar mesej terus ke pasukan sokongan kami. Anda juga boleh melampirkan tangkapan skrin masalah tersebut."
      }
    ],
    'tr': [
      {
        'q': "FinLoop nedir?",
        'a': "FinLoop, premium, güvenli ve modern bir kişisel finans takip uygulamasıdır. İşlemleri yönetmenize, grup harcamalarını bölüştürmenize, bütçeler belirlemenize ve harcama analizlerini görüntülemenize yardımcı olur."
      },
      {
        'q': "Verilerim nerede saklanıyor?",
        'a': "Verileriniz güvenli bir şekilde Firebase Cloud Firestore'da saklanır. Bu, giriş yaptığınız tüm cihazlarınız arasında gerçek zamanlı senkronizasyon sağlar."
      },
      {
        'q': "Parolam ve biyometrik verilerim güvende mi?",
        'a': "Evet. FinLoop, parolalar ve biyometri için cihazınızın yerel işletim sistemi güvenliğini kullanır. Ham biyometrik verilerinize asla erişmeyiz, saklamayız veya iletmeyiz."
      },
      {
        'q': "Verilerimi nasıl dışa aktarım?",
        'a': "İşlem geçmişinizi İşlemler ekranından PDF olarak dışa aktarabilir veya Ayarlar -> Yedekle menüsünden tüm kayıtları bir Excel tablosuna yedekleyebilirsiniz."
      },
      {
        'q': "Destek ekibiyle nasıl iletişime geçebilirim?",
        'a': "Destek ekibimize doğrudan mesaj göndermek için Ayarlar -> Geri Bildirim bölümüne gidin. Ayrıca sorunun ekran görüntüsünü de ekleyebilirsiniz."
      }
    ]
  };

  @override
  Widget build(BuildContext context) {
    final languageProvider = context.watch<LanguageProvider>();
    final code = languageProvider.languageCode;
    final onSurfaceColor = Theme.of(context).colorScheme.onSurface;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final faqs = _faqData[code] ?? _faqData['en']!;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: onSurfaceColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          context.translate('faq'),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: onSurfaceColor,
          ),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        itemCount: faqs.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final faq = faqs[index];
          return Theme(
            data: Theme.of(context).copyWith(
              dividerColor: Colors.transparent,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              hoverColor: Colors.transparent,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? Theme.of(context).colorScheme.surface : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ExpansionTile(
                backgroundColor: Colors.transparent,
                collapsedBackgroundColor: Colors.transparent,
                title: Text(
                  faq['q']!,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: onSurfaceColor,
                  ),
                ),
                iconColor: onSurfaceColor.withValues(alpha: 0.8),
                collapsedIconColor: onSurfaceColor.withValues(alpha: 0.5),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(
                    height: 16,
                    thickness: 0.5,
                    color: onSurfaceColor.withValues(alpha: 0.08),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    faq['a']!,
                    style: TextStyle(
                      fontSize: 13,
                      color: onSurfaceColor.withValues(alpha: 0.65),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

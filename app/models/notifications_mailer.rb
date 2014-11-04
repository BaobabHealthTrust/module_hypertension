class NotificationsMailer < ActionMailer::Base
  def send_email(subject, body, filename, recipient)
		recipients recipient
		from 'bartbaobab@gmail.com' 
		subject subject
		sent_on Time.now 
		body body

    attachment :content_type => 'application/pdf',
               :body => File.read("/tmp/#{filename}"),
               :filename => "validation Rules"
  end  
end

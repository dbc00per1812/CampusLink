// LegalDocumentScreen - Display legal documents in-app using WebView
// Supports both PDF files (preferred) and embedded HTML content (fallback)
import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  ActivityIndicator,
  Platform,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { useNavigation, useRoute, RouteProp } from '@react-navigation/native';
import { WebView } from 'react-native-webview';
import * as FileSystem from 'expo-file-system';
import { Asset } from 'expo-asset';
import { useColors } from '../../context/ThemeContext';

type DocumentType = 'terms' | 'privacy' | 'community';

type LegalDocumentRouteParams = {
  LegalDocument: { documentType: DocumentType };
};

const DOCUMENT_TITLES = {
  terms: 'Terms of Service',
  privacy: 'Privacy Policy',
  community: 'Community Guidelines',
};

// PDF assets - loaded from mobile/assets/legal/ folder
const PDF_ASSETS: Record<DocumentType, any> = {
  terms: require('../../../assets/legal/terms.pdf'),
  privacy: require('../../../assets/legal/privacy.pdf'),
  community: require('../../../assets/legal/community-guidelines.pdf'),
};

// Generate themed HTML wrapper
const generateHtml = (content: string, colors: any): string => {
  return `
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <style>
        * {
            box-sizing: border-box;
        }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            line-height: 1.6;
            color: ${colors.textPrimary};
            background-color: ${colors.background};
            margin: 0;
            padding: 16px;
            padding-bottom: 80px;
            font-size: 15px;
        }
        h1 {
            color: ${colors.textPrimary};
            font-size: 24px;
            border-bottom: 3px solid ${colors.primary};
            padding-bottom: 10px;
            margin-top: 0;
        }
        h2 {
            color: ${colors.textPrimary};
            font-size: 18px;
            margin-top: 24px;
            margin-bottom: 12px;
        }
        h3 {
            color: ${colors.textPrimary};
            font-size: 16px;
            margin-top: 16px;
            margin-bottom: 8px;
        }
        p {
            color: ${colors.textSecondary};
            margin: 8px 0;
        }
        ul {
            padding-left: 20px;
            margin: 8px 0;
        }
        li {
            color: ${colors.textSecondary};
            margin: 6px 0;
        }
        .meta {
            color: ${colors.textTertiary};
            font-size: 13px;
            margin-bottom: 20px;
        }
        .contact-box {
            background-color: ${colors.surfaceSecondary};
            padding: 16px;
            border-radius: 8px;
            margin: 16px 0;
        }
        .important {
            background-color: ${colors.warningLight || 'rgba(255, 193, 7, 0.1)'};
            border-left: 4px solid ${colors.warning || '#ffc107'};
            padding: 12px;
            margin: 16px 0;
        }
        .important p {
            color: ${colors.textPrimary};
            margin: 0;
        }
        a {
            color: ${colors.primary};
        }
        .rule-section {
            background-color: ${colors.surfaceSecondary};
            padding: 16px;
            margin: 16px 0;
            border-radius: 8px;
            border-left: 4px solid ${colors.primary};
        }
        .warning {
            background-color: ${colors.warningLight || 'rgba(255, 193, 7, 0.1)'};
            border-left: 4px solid ${colors.warning || '#ffc107'};
            padding: 12px;
            margin: 16px 0;
        }
        .intro {
            background-color: ${colors.surfaceSecondary};
            padding: 16px;
            border-radius: 8px;
            margin-bottom: 20px;
            border-left: 4px solid ${colors.primary};
        }
    </style>
</head>
<body>
${content}
</body>
</html>
`;
};

// Terms of Service Content
const TERMS_CONTENT = `
<h1>Terms of Service</h1>

<div class="meta">
    <strong>Dated:</strong> September 22, 2025
</div>

<p>Welcome to our online community! The entire team at CampusLink LLC is excited to have you visit our Site.</p>

<p>When you access our Site or use our online services, you enter into a legal agreement, which is what you see below. It may seem long, but that's because we've tried to make it as clear as we can. We've also bolded or put in all caps a few areas that talk about important legal rights, including the following:</p>

<div class="important">
    <p><strong>These Terms of Service include an agreement to resolve any disputes through binding arbitration that includes a class action waiver, as well as important disclaimers, warranties and limitations on liability.</strong></p>
</div>

<p>This agreement applies to every product or service we offer, including, but not exclusively, smartphone and tablet applications, websites, emails, and other communications to and from us (separately and collectively the "Site"). We're always happy to hear from you if you have any questions or suggestions. You can contact us by email at <a href="mailto:legal.campuslink@gmail.com">legal.campuslink@gmail.com</a>.</p>

<h2>A. Your Acceptance</h2>

<p>1. This Site belongs to CampusLink LLC ("we," "us" or sometimes "Company"). By purchasing from, using or visiting this Site or any product, software, data feed, or service provided to you on, from, or through this Site (collectively the "Service"), you signify your agreement to (1) these terms and conditions (the "Terms of Service"), (2) our Privacy Policy, and (3) our Community Guidelines, all of which are found at our Site and incorporated herein by this reference. Collectively, these terms and conditions, the Privacy Policy, and Community Guidelines are also referred to and treated as Terms of Service. The Terms of Service include products or service offerings, conditions, terms, descriptions, details and pricing, all of which are found throughout this Site and all of which are incorporated in and included as part of these Terms of Service. If you do not agree to any of the Terms of Service, please do not use the Service.</p>

<p>2. Although we may attempt (but are not obligated) to notify you when changes are made to these Terms of Service, you should periodically review the most up-to-date version at the Company Site, because you hereby agree to abide by and honor the most up-to-date version of the Terms of Service. By each use of the Company Site or services, you agree to be bound by the latest version of these Terms of Service, Privacy Policy, and Community Guidelines. Company may, in its sole discretion, modify or revise these Terms of Service and policies at any time, and you agree to be bound by such modifications or revisions. Nothing in these Terms of Service shall be deemed to confer any third-party rights or benefits.</p>

<h2>B. Service</h2>

<p>1. These Terms of Service apply to all users of the Service, including users who are also contributors of Content on the Service. "Content" includes the text, software, scripts, graphics, photos, sounds, music, videos, audiovisual combinations, interactive features and other materials you may view on, access through, or contribute to the Service. The Service includes all aspects of Company, including but is not limited to all products, software and services offered via the Company Site.</p>

<p>2. The Service may contain links to third-party websites that are not owned or controlled by Company. Company has no control over and assumes no responsibility for the content, privacy policies or practices of any third-party websites. In addition, Company will not and cannot censor or edit the content of any third-party site. By using the Service, you expressly relieve and release Company from any and all liability arising from your use of any third-party website. Accordingly, we encourage you and you agree to be aware of and to read the terms and conditions and privacy policy of each other website that you visit.</p>

<h2>C. Company Accounts</h2>

<p>1. In order to access some features of the Service, you may be asked to create a Company account. You may never use another's account without permission. When creating your account, you must provide accurate and complete information. You are solely responsible for the activity that occurs on your account, and you must keep your account password secure. You must notify Company immediately of any breach of security or unauthorized use of your account. Company is not responsible for any act of any other person on your account.</p>

<p>2. Although Company will not be liable for your losses or injury caused by any unauthorized use of your account, you may be liable for the losses of Company or others due to such unauthorized use.</p>

<h2>D. General Use of the Service—Permissions and Restrictions</h2>

<p>Company hereby grants you permission to access and use the Service as set forth in these Terms of Service, provided that:</p>

<p>1. You agree not to distribute in any medium any part of the Service or the Content without Company's prior written authorization, unless Company makes available the means for such distribution through functionality offered by the Service.</p>

<p>2. You agree not to alter or modify any part of the Service.</p>

<p>3. You agree not to access Content through any technology or means other than the Service itself or other explicitly authorized means Company may designate.</p>

<p>4. You agree not to use the Service for any of the following commercial uses unless you obtain Company's prior written approval:</p>
<ul>
    <li>the sale of access to the Service; or</li>
    <li>the sale of advertising, sponsorships, or promotions placed on or within the Service or Content.</li>
</ul>

<p>5. You agree not to use or launch any automated system, including without limitation, "robots," "spiders," or "offline readers," that access the Service in a manner that sends more request messages to the Company servers in a given period of time than a human can reasonably produce in the same period by using a conventional on-line web browser. Company reserves the right to revoke these exceptions either generally or in specific cases. You agree not to collect or harvest any personally identifiable information, including account names, from the Service, nor to use the communication systems provided by the Service for any commercial solicitation purposes.</p>

<p>6. In your use of the Service, you will comply with all applicable laws.</p>

<p>7. Company reserves the right to discontinue, change or alter any aspect of the Service at any time.</p>

<h2>E. Your Use of Content</h2>

<p>1. The Content on the Service, and the trademarks, service marks and logos ("Marks") on the Service, are owned by or licensed to Company, subject to copyright and other intellectual property rights under the law.</p>

<p>2. Content is provided to you AS IS. You may access Content for your informational and personal use solely as intended through the provided functionality of the Service and as permitted under these Terms of Service. You shall not download any Content unless you see a "download" or similar link displayed by Company on the Service for that Content. You shall not copy, reproduce, distribute, transmit, broadcast, display, sell, license, or otherwise exploit any Content for any other purpose without the prior written consent of Company or the respective licensors of the Content. Company and its licensors reserve all rights not expressly granted in and to the Service and the Content.</p>

<p>3. You agree not to circumvent, disable or otherwise interfere with security-related features of the Service or features that prevent or restrict use or copying of any Content or enforce limitations on use of the Service or the Content therein.</p>

<p>4. You understand that when using the Service, you will be exposed to Content from a variety of sources, and that Company is not responsible for the accuracy, usefulness, legality, safety, or intellectual property rights of or relating to such Content. You further understand and acknowledge that you may be exposed to Content that is inaccurate, offensive, indecent, or objectionable, and you agree to waive and release, and hereby do waive and release, any legal or equitable rights or remedies you have or may have against Company with respect thereto.</p>

<h2>F. Your Content and Conduct</h2>

<p>1. As a Company account holder you may submit Content to the Service. You understand that Company does not promise to provide or guarantee any confidentiality with respect to any Content you submit.</p>

<p>2. You retain all of your ownership rights in your Content. However, by submitting Content to Company, you hereby grant Company a worldwide, non-exclusive, royalty-free, sub-licensable and transferable license to use, reproduce, distribute, prepare derivative works of, display, and perform the Content in connection with the Service and Company's business.</p>

<p>3. You further agree that you will not submit to the Service any Content or other material that is contrary to the Company Community Guidelines or material contrary to applicable local, state, national, and international laws and regulations.</p>

<h2>G. Account Termination Policy</h2>

<p>1. Company will terminate a user's access to the Service if, under appropriate circumstances, the user is determined to be a repeat or significant infringer.</p>

<p>2. Company reserves the right to decide whether Content violates these Terms of Service for reasons other than copyright infringement, such as, but not limited to, pornography, obscenity, illegality, or excessive length. Company may at any time, without prior notice and in its sole discretion, remove such Content and/or terminate a user's account for submitting such material in violation of these Terms of Service.</p>

<h2>H. Digital Millennium Copyright Act</h2>

<h3>1. DMCA Take-Down Notices</h3>
<p>If you are a copyright owner or an agent thereof and believe that any Content infringes upon your copyrights, you may submit a notification pursuant to the Digital Millennium Copyright Act ("DMCA") by providing our Copyright Agent with the following information in writing:</p>

<ul>
    <li>A physical or electronic signature of a person authorized to act on behalf of the owner of an exclusive right that is allegedly infringed;</li>
    <li>Identification of the copyrighted work claimed to have been infringed;</li>
    <li>Identification of the material that is claimed to be infringing and where it is located on the Service;</li>
    <li>Information reasonably sufficient to permit the service provider to contact you;</li>
    <li>A statement that you have a good faith belief that use of the material is not authorized by the copyright owner;</li>
    <li>A statement that the information in the notification is accurate, and under penalty of perjury, that you are authorized to act on behalf of the owner of the copyright that is allegedly infringed.</li>
</ul>

<div class="contact-box">
    <p><strong>Company's designated Copyright Agent:</strong><br>
    Copyright Agent, Legal Department<br>
    1048B Sagamore Pkwy W<br>
    West Lafayette, IN 47906<br>
    <a href="mailto:legal.campuslink@gmail.com">legal.campuslink@gmail.com</a></p>
</div>

<h3>2. Counter-Notice</h3>
<p>If you believe that your Content that was removed (or to which access was disabled) is not infringing, or that you have the authorization from the copyright owner, you may send a counter-notice containing the following information to the Copyright Agent:</p>
<ul>
    <li>Your physical or electronic signature;</li>
    <li>Identification of the Content that has been removed and the location at which it appeared before removal;</li>
    <li>A statement that you have a good faith belief that the Content was removed as a result of mistake or misidentification;</li>
    <li>Your name, address, telephone number, and e-mail address, a statement that you consent to the jurisdiction of the federal court in Indianapolis, Indiana.</li>
</ul>

<h2>I. Warranty Disclaimer</h2>

<div class="important">
    <p>YOU AGREE THAT YOUR USE OF THE SERVICES SHALL BE AT YOUR SOLE RISK. TO THE FULLEST EXTENT PERMITTED BY LAW, COMPANY, ITS OWNERS, OFFICERS, MANAGERS, EMPLOYEES, AND AGENTS DISCLAIM ALL WARRANTIES, EXPRESS OR IMPLIED, IN CONNECTION WITH THE SERVICES AND YOUR USE THEREOF. COMPANY MAKES NO WARRANTIES OR REPRESENTATIONS ABOUT THE ACCURACY OR COMPLETENESS OF THIS SITE'S CONTENT OR THE CONTENT OF ANY SITES LINKED TO THIS SITE AND ASSUMES NO LIABILITY OR RESPONSIBILITY FOR ANY (I) ERRORS, MISTAKES, OR INACCURACIES OF CONTENT, (II) PERSONAL INJURY OR PROPERTY DAMAGE, OF ANY NATURE WHATSOEVER, RESULTING FROM YOUR ACCESS TO AND USE OF OUR SERVICES, (III) ANY UNAUTHORIZED ACCESS TO OR USE OF OUR SECURE SERVERS AND/OR ANY AND ALL PERSONAL INFORMATION AND/OR FINANCIAL INFORMATION STORED THEREIN, (IV) ANY INTERRUPTION OR CESSATION OF TRANSMISSION TO OR FROM OUR SERVICES, (V) ANY BUGS, VIRUSES, TROJAN HORSES, OR THE LIKE WHICH MAY BE TRANSMITTED TO OR THROUGH OUR SERVICES BY ANY THIRD PARTY, AND/OR (VI) ANY ERRORS OR OMISSIONS IN ANY CONTENT OR FOR ANY LOSS OR DAMAGE OF ANY KIND INCURRED AS A RESULT OF THE USE OF ANY CONTENT POSTED, EMAILED, TRANSMITTED, OR OTHERWISE MADE AVAILABLE VIA THE SERVICES.</p>
</div>

<h2>J. Limitation of Liability</h2>

<div class="important">
    <p>IN NO EVENT SHALL COMPANY, ITS OFFICERS, OWNERS, MANAGERS, EMPLOYEES, OR AGENTS, BE LIABLE TO YOU FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, PUNITIVE, OR CONSEQUENTIAL DAMAGES WHATSOEVER RESULTING FROM ANY (I) ERRORS, MISTAKES, OR INACCURACIES OF CONTENT, (II) PERSONAL INJURY OR PROPERTY DAMAGE, OF ANY NATURE WHATSOEVER, RESULTING FROM YOUR ACCESS TO AND USE OF OUR SERVICES, (III) ANY UNAUTHORIZED ACCESS TO OR USE OF OUR SECURE SERVERS AND/OR ANY AND ALL PERSONAL INFORMATION AND/OR FINANCIAL INFORMATION STORED THEREIN, (IV) ANY INTERRUPTION OR CESSATION OF TRANSMISSION TO OR FROM OUR SERVICES, (V) ANY BUGS, VIRUSES, TROJAN HORSES, OR THE LIKE, WHICH MAY BE TRANSMITTED TO OR THROUGH OUR SERVICES BY ANY THIRD PARTY, AND/OR (VI) ANY ERRORS OR OMISSIONS IN ANY CONTENT OR FOR ANY LOSS OR DAMAGE OF ANY KIND INCURRED AS A RESULT OF YOUR USE OF ANY CONTENT POSTED, EMAILED, TRANSMITTED, OR OTHERWISE MADE AVAILABLE VIA THE SERVICES, WHETHER BASED ON WARRANTY, CONTRACT, TORT, OR ANY OTHER LEGAL THEORY, AND WHETHER OR NOT THE COMPANY IS ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.</p>
    <p>YOU SPECIFICALLY ACKNOWLEDGE THAT COMPANY SHALL NOT BE LIABLE FOR CONTENT OR THE DEFAMATORY, OFFENSIVE, OR ILLEGAL CONDUCT OF ANY THIRD PARTY AND THAT THE RISK OF HARM OR DAMAGE FROM THE FOREGOING RESTS ENTIRELY WITH YOU.</p>
</div>

<h2>K. Indemnity</h2>

<p>To the extent permitted by applicable law, you agree to defend, indemnify and hold harmless Company, its owners, officers, managers, employees and agents, from and against any and all claims, damages, obligations, losses, liabilities, costs or debt, and expenses (including but not limited to attorney's fees) arising from: (i) your use of and access to the Service; (ii) your violation of any term of these Terms of Service; (iii) your violation of any third party right, including without limitation any copyright, property, or privacy right; or (iv) any claim that your Content caused damage to a third party. This defense and indemnification obligation will survive these Terms of Service and your use of the Service.</p>

<h2>L. Ability to Accept Terms of Service</h2>

<p>You affirm that you are either more than 18 years of age, or an emancipated minor, or possess legal parental or guardian consent, and are fully able and competent to enter into the terms, conditions, obligations, affirmations, representations, and warranties set forth in these Terms of Service, and to abide by and comply with these Terms of Service. In any case, you affirm that you are over the age of 13, as the Service is not intended for children under 13. If you are under 13 years of age, then please do not use the Service.</p>

<h2>M. Assignment</h2>

<p>These Terms of Service, and any rights and licenses granted hereunder, may not be transferred or assigned by you, but may be assigned by Company without restriction.</p>

<h2>N. General</h2>

<p>You agree that: (i) the Service shall be deemed solely based in Indiana; and (ii) the Service shall be deemed a passive Site that does not give rise to personal jurisdiction over Company, either specific or general, in jurisdictions other than Indiana. These Terms of Service shall be governed by the internal substantive laws of the State of Indiana, without respect to its conflict of laws principles. Any claim or dispute between you and Company that arises in whole or in part from the Service shall be decided exclusively by a court of competent jurisdiction located in Tippecanoe County, Indiana.</p>

<p>The Terms of Service, including all other documents referenced and incorporated herein, and any other legal notices published by Company on the Service, shall constitute the entire agreement between you and Company concerning the Service. If any provision of these Terms of Service is deemed invalid by a court of competent jurisdiction, the invalidity of such provision shall not affect the validity of the remaining provisions of these Terms of Service, which shall remain in full force and effect.</p>

<p>Company reserves the right to amend these Terms of Service at any time and without notice, and it is your responsibility to review these Terms of Service for any changes. Your use of the Service following any amendment of these Terms of Service will signify your assent to and acceptance of its revised terms.</p>

<div class="important">
    <p><strong>YOU AND COMPANY AGREE THAT ANY CAUSE OF ACTION ARISING OUT OF OR RELATED TO THE SERVICES MUST COMMENCE WITHIN ONE (1) YEAR AFTER THE CAUSE OF ACTION ACCRUES. OTHERWISE, SUCH CAUSE OF ACTION IS PERMANENTLY BARRED.</strong></p>
</div>

<div class="contact-box">
    <h2>Contact Information</h2>
    <p><strong>Company:</strong> CampusLink LLC<br>
    <strong>Address:</strong> 1048B Sagamore Pkwy W, West Lafayette, IN 47906<br>
    <strong>Email:</strong> <a href="mailto:legal.campuslink@gmail.com">legal.campuslink@gmail.com</a></p>
</div>
`;

// Privacy Policy Content
const PRIVACY_CONTENT = `
<h1>Privacy Policy</h1>

<div class="meta">
    <strong>Effective Date:</strong> January 29, 2025<br>
    <strong>Last Updated:</strong> October 28, 2025
</div>

<h2>Controller Information</h2>
<p>
    <strong>Company:</strong> CampusLink LLC<br>
    <strong>Contact:</strong> darragh.b3272@gmail.com<br>
    <strong>State of Organization:</strong> Indiana
</p>

<h2>Overview</h2>
<p>CampusLink is a peer-to-peer marketplace mobile application that facilitates student-to-student sales of physical goods and services. This Privacy Policy describes how we collect, use, and protect your personal information when you use our mobile application.</p>

<h2>What We Collect</h2>

<h3>Personal Information</h3>
<ul>
    <li><strong>Name and Email Address:</strong> Required for account creation and verification</li>
    <li><strong>Profile Information:</strong> Bio, profile picture (optional)</li>
    <li><strong>Authentication Data:</strong> Encrypted passwords and session tokens</li>
    <li><strong>Location Address:</strong> Optional user-provided address for calculating distances to sellers. Your exact address is never shown to other users.</li>
</ul>

<h3>Content You Create</h3>
<ul>
    <li><strong>Listings:</strong> Product/service descriptions, photos, pricing, categories</li>
    <li><strong>Messages:</strong> Direct messages with other users through our messaging system</li>
    <li><strong>Ratings and Reviews:</strong> Feedback you provide about transactions</li>
    <li><strong>Reports:</strong> Content moderation reports you submit</li>
</ul>

<h3>Device and Technical Information</h3>
<ul>
    <li><strong>Device Information:</strong> Device type, operating system, app version</li>
    <li><strong>Push Notification Tokens:</strong> For sending you notifications</li>
    <li><strong>IP Address:</strong> For security and fraud prevention</li>
    <li><strong>Usage Data:</strong> App interactions, feature usage, error logs</li>
</ul>

<h3>Payment Information</h3>
<ul>
    <li><strong>Payment Methods:</strong> Credit/debit cards and Apple Pay (processed securely via Stripe)</li>
    <li><strong>Stripe Connect Account Data:</strong> For sellers (handled by Stripe)</li>
    <li><strong>Transaction Records:</strong> Order history, payment amounts, escrow information</li>
    <li><strong>Bank Account Information:</strong> For payouts (stored securely by Stripe)</li>
</ul>

<h3>Photos and Media</h3>
<ul>
    <li><strong>Listing Photos:</strong> Images you upload for your listings</li>
    <li><strong>Profile Pictures:</strong> Optional profile photos</li>
    <li><strong>Camera Access:</strong> For taking photos directly in the app</li>
</ul>

<h2>Sources of Data</h2>
<ul>
    <li><strong>You:</strong> Information you provide directly when creating an account, listings, or messages</li>
    <li><strong>Your Device:</strong> Technical information automatically collected from your device</li>
    <li><strong>Stripe:</strong> Payment processing and verification data</li>
    <li><strong>Supabase:</strong> Our database and authentication provider</li>
    <li><strong>Google Maps API:</strong> Used for geocoding addresses and calculating walking distances between buyers and sellers</li>
</ul>

<h2>How We Use Your Data</h2>

<h3>App Functionality</h3>
<ul>
    <li><strong>Account Management:</strong> Creating and maintaining your user account</li>
    <li><strong>Authentication:</strong> Verifying your identity and campus email</li>
    <li><strong>Marketplace Operations:</strong> Facilitating listings, offers, and transactions</li>
    <li><strong>Messaging:</strong> Enabling communication between buyers and sellers</li>
    <li><strong>Payments:</strong> Processing transactions through Stripe Connect (including Apple Pay)</li>
</ul>

<h3>Safety and Security</h3>
<ul>
    <li><strong>Fraud Prevention:</strong> Detecting and preventing fraudulent activity</li>
    <li><strong>Content Moderation:</strong> Reviewing reported content and user behavior</li>
    <li><strong>Dispute Resolution:</strong> Investigating and resolving transaction disputes</li>
    <li><strong>Account Security:</strong> Protecting against unauthorized access</li>
</ul>

<h3>Legal Compliance</h3>
<ul>
    <li><strong>Tax Requirements:</strong> Maintaining records as required by law</li>
    <li><strong>Law Enforcement:</strong> Responding to valid legal requests</li>
    <li><strong>Terms Enforcement:</strong> Ensuring compliance with our Terms of Service</li>
</ul>

<h3>Product Improvement</h3>
<ul>
    <li><strong>Analytics:</strong> Understanding how users interact with our app</li>
    <li><strong>Bug Fixes:</strong> Identifying and resolving technical issues</li>
    <li><strong>Feature Development:</strong> Improving existing features and developing new ones</li>
</ul>

<h2>Data Sharing</h2>

<h3>We Share Data With:</h3>
<ul>
    <li><strong>Service Providers:</strong> Supabase (database), Stripe (payments including Apple Pay)</li>
    <li><strong>Other Users:</strong> Your public profile information and listings are visible to other users</li>
    <li><strong>Legal Authorities:</strong> When required by law or to protect our rights</li>
    <li><strong>Business Transfers:</strong> In case of merger, acquisition, or sale of assets</li>
</ul>

<h3>We Do NOT:</h3>
<ul>
    <li><strong>Sell your data</strong> to third parties</li>
    <li><strong>Use your data</strong> for third-party advertising</li>
    <li><strong>Share personal information</strong> beyond what's necessary for app functionality</li>
</ul>

<h2>Data Retention</h2>

<h3>Account Data</h3>
<ul>
    <li><strong>Active Accounts:</strong> Retained while your account is active</li>
    <li><strong>Deleted Accounts:</strong> Permanently deleted within 30 days of account deletion request</li>
</ul>

<h3>Transaction Data</h3>
<ul>
    <li><strong>Order Records:</strong> Retained for 7 years for tax compliance</li>
    <li><strong>Payment Information:</strong> Handled by Stripe according to their retention policies</li>
</ul>

<h3>Messages and Content</h3>
<ul>
    <li><strong>Messages:</strong> Retained while your account is active</li>
    <li><strong>Listings:</strong> Retained while active, archived when sold or deleted</li>
    <li><strong>Photos:</strong> Retained while associated with active listings</li>
</ul>

<h3>Technical Data</h3>
<ul>
    <li><strong>Logs and Analytics:</strong> Retained for 12-24 months</li>
    <li><strong>Error Reports:</strong> Retained for 6 months for debugging purposes</li>
</ul>

<h2>Security Measures</h2>

<h3>Technical Safeguards</h3>
<ul>
    <li><strong>Encryption:</strong> All data encrypted in transit and at rest</li>
    <li><strong>Row-Level Security:</strong> Database access controls based on user identity</li>
    <li><strong>Secure Authentication:</strong> Industry-standard authentication protocols</li>
    <li><strong>Regular Security Updates:</strong> Keeping systems and dependencies current</li>
</ul>

<h3>Access Controls</h3>
<ul>
    <li><strong>Least Privilege:</strong> Staff access limited to necessary functions only</li>
    <li><strong>Audit Logging:</strong> Monitoring access to sensitive data</li>
    <li><strong>Secure Development:</strong> Following security best practices in code development</li>
</ul>

<h2>Your Rights</h2>

<h3>Access and Control</h3>
<ul>
    <li><strong>View Your Data:</strong> Access your personal information through the app</li>
    <li><strong>Update Information:</strong> Modify your profile and account settings</li>
    <li><strong>Delete Account:</strong> Request account deletion through the app settings</li>
    <li><strong>Data Portability:</strong> Request a copy of your data</li>
</ul>

<h3>Communication Preferences</h3>
<ul>
    <li><strong>Push Notifications:</strong> Control notification types in app settings</li>
    <li><strong>Email Communications:</strong> Opt out of marketing emails</li>
    <li><strong>Quiet Hours:</strong> Set times when you don't want to receive notifications</li>
</ul>

<h3>How to Exercise Your Rights</h3>
<ul>
    <li><strong>In-App:</strong> Use the Settings screen to manage your preferences</li>
    <li><strong>Email:</strong> Contact us at support@campuslink.app</li>
    <li><strong>Account Deletion:</strong> Use the "Delete Account" option in Settings</li>
</ul>

<h2>Children's Privacy</h2>
<p>CampusLink is not intended for users under 18 years of age. We do not knowingly collect personal information from children under 18. If we learn that we have collected personal information from a child under 18, we will delete that information immediately and disable the account unless we receive verified parental consent.</p>

<h2>International Data Transfers</h2>
<p>Our services are primarily designed for users in the United States. Data may be processed by our service providers (Supabase, Stripe) who may be located outside the United States. We ensure appropriate safeguards are in place for any international data transfers.</p>

<h2>Changes to This Policy</h2>
<p>We may update this Privacy Policy from time to time. We will notify you of any material changes by:</p>
<ul>
    <li><strong>In-App Notification:</strong> Showing a notice when you open the app</li>
    <li><strong>Email:</strong> Sending notice to your registered email address</li>
    <li><strong>Updated Date:</strong> Changing the "Last Updated" date at the top of this policy</li>
</ul>
<p>Your continued use of the app after changes become effective constitutes acceptance of the updated policy.</p>

<div class="contact-box">
    <h2>Contact Us</h2>
    <p>If you have questions about this Privacy Policy or our data practices, please contact us:</p>
    <p>
        <strong>Email:</strong> support@campuslink.app<br>
        <strong>Subject Line:</strong> Privacy Policy Inquiry
    </p>
</div>

<h2>Change Log</h2>
<div class="intro">
    <p><strong>Version 1.1</strong> - October 28, 2025</p>
    <ul>
        <li>Added distance feature: optional user-provided addresses for showing distance between buyers and sellers</li>
        <li>Added Google Maps API integration for geocoding and distance calculations</li>
        <li>Added privacy controls: users can choose approximate, exact, or hidden distance display</li>
        <li>Updated privacy policy to reflect approximate location data collection</li>
    </ul>
    <p><strong>Version 1.0</strong> - January 29, 2025</p>
    <ul>
        <li>Initial privacy policy created</li>
        <li>Comprehensive coverage of all data collection and usage</li>
        <li>App Store compliance documentation</li>
        <li>User rights and contact information included</li>
        <li>Apple Pay payment method explicitly mentioned</li>
    </ul>
</div>
`;

// Community Guidelines Content
const COMMUNITY_CONTENT = `
<h1>Community Guidelines</h1>

<div class="meta">
    <strong>Effective Date:</strong> September 22, 2025<br>
    <strong>Last Updated:</strong> November 12, 2025
</div>

<div class="intro">
    <p><strong>Welcome to CampusLink!</strong></p>
    <p>Here is additional guidance on what is acceptable and unacceptable at CampusLink LLC. These guidelines help ensure a safe, respectful, and productive marketplace for all members of our campus community.</p>
</div>

<h2>Core Community Rules</h2>

<div class="rule-section">
    <h3>1. Language Standards</h3>
    <p><strong>No vulgar language is tolerated on marketplace listings.</strong></p>
    <p>Keep your listings professional and respectful. This includes product descriptions, titles, and any communication within the platform.</p>
</div>

<div class="rule-section">
    <h3>2. Prohibited Content</h3>
    <div class="warning">
        <p><strong>Explicit or suggestive posts relating to the sale of substances including but not limited to alcohol, drugs or any illegal activities will not be tolerated and may result in legal ramifications.</strong></p>
    </div>
    <p>CampusLink is for legitimate goods and services only. Listings that violate this rule will be immediately removed and may result in account termination and reporting to appropriate authorities.</p>
</div>

<div class="rule-section">
    <h3>3. Dispute Policy</h3>
    <p><strong>If a user is involved in more than one payment dispute, they will be removed from the platform.</strong></p>
    <p>We take transaction integrity seriously. Multiple disputes indicate a pattern of problematic behavior and will result in permanent account suspension.</p>
</div>

<div class="rule-section">
    <h3>4. Communication & Availability</h3>
    <p><strong>Respond in a timely manner to those interested in your listing.</strong> If a listing is no longer available for sale, please remove the post.</p>
    <p>Good communication is essential for a thriving marketplace. Update your listings promptly and respond to inquiries within 24 hours when possible.</p>
</div>

<div class="rule-section">
    <h3>5. Service Arrangements</h3>
    <p><strong>For certain services like tutoring, communicate to find a time that works for both members, and is in a safe public place on campus.</strong></p>
    <p>Always meet in well-lit, public areas. Never share your home address or meet in isolated locations. Safety first!</p>
</div>

<div class="rule-section">
    <h3>6. Service Quality</h3>
    <p><strong>For tutoring services, tutors should make sure they are familiar with the relevant subject material beforehand.</strong></p>
    <p>Only offer services you're qualified to provide. Misrepresenting your skills or qualifications is a violation of these guidelines.</p>
</div>

<h2>Content Standards</h2>

<h3>Pornography, Sex and Nudity</h3>
<p>Pornography is difficult to define, but we know it when we see it, and we do not permit it on our Site. Most nudity and sexual content is not allowed. If content is intended to be sexually provocative, it is unacceptable.</p>

<h3>Hate Speech</h3>
<p>"Hate speech" refers to content that promotes hatred against members of a protected group. For instance, racist or sexist content may be considered hate speech. It is generally okay to criticize ideas or institutions, but not okay to make insulting generalizations about people based on their race, religion, gender, nationality, or other protected characteristics.</p>

<h3>Shocking and Disgusting Content</h3>
<p>It's not okay to post violent or gory content that's primarily intended to be shocking, sensational or disrespectful. Content should be appropriate for a diverse campus community.</p>

<h3>Dangerous or Illegal Acts</h3>
<p>We draw the line at content that's intended to incite violence or encourage dangerous, illegal activities that have an inherent risk of serious physical harm or death. This includes any content that promotes or facilitates illegal activities.</p>

<h3>Children</h3>
<p>Content involving children (anyone under the age of 18) is particularly sensitive. Such content should never be sexually suggestive or violent. Since CampusLink requires users to be 18+, content involving minors should be limited and appropriate.</p>

<h3>Copyright & Trademarks</h3>
<p>When you create something original, you own the copyright or possibly a trademark for it. Likewise, when other people create content, they may have a copyright or trademark to it. As a creative community, it's essential that everyone on our Site respect the copyrights and trademarks of others.</p>
<p><strong>Best Practice:</strong> If you're not sure if something will violate someone's copyright, the safest thing to do is to create something completely original. If it's all yours, you never have to worry about copyrights or trademark rights.</p>

<h3>Privacy</h3>
<p>If a photo or video you've posted features people who are readily identifiable and who haven't consented to being featured, there's a chance they'll file a privacy complaint seeking its removal. Don't post other people's personal information, including phone numbers, addresses, credit card numbers, and government IDs.</p>
<p><strong>We're serious about keeping our users safe and suspend accounts that violate people's privacy.</strong></p>

<h3>Harassment</h3>
<p>It comes down to respect. CampusLink is all about sharing and interacting with the community in respectful ways. If you're not sure whether a comment or message crosses the line, follow a simple rule of thumb: if you wouldn't say it to someone's face, don't say it on CampusLink.</p>
<p>If you're looking to attack, harass, demean, or impersonate others, go elsewhere.</p>

<h3>Impersonation</h3>
<p>Impersonating someone by copying that person's profile, using a similar username, or posing as that person in comments or messages is considered impermissible. Please avoid any form of impersonation or harassing activity on the site.</p>

<h3>Threats</h3>
<p>Users shouldn't feel threatened when they're on our Site. Period. Don't make threatening comments or send threatening messages to other users. Any threats of violence will result in immediate account suspension and may be reported to law enforcement.</p>

<h2>Marketplace-Specific Rules</h2>

<h3>Listing Quality</h3>
<ul>
    <li>Use clear, accurate photos of items you're selling</li>
    <li>Provide honest, complete descriptions</li>
    <li>Price items fairly and accurately</li>
    <li>Update or remove sold items promptly</li>
</ul>

<h3>Transaction Conduct</h3>
<ul>
    <li>Honor your commitments to buy or sell</li>
    <li>Communicate clearly about meetup times and locations</li>
    <li>Be on time for scheduled exchanges</li>
    <li>Treat items with care if trying before buying</li>
</ul>

<h3>Safety Best Practices</h3>
<ul>
    <li>Meet in public, well-lit campus locations</li>
    <li>Consider bringing a friend to exchanges</li>
    <li>Trust your instincts - if something feels off, it probably is</li>
    <li>Report suspicious behavior or listings immediately</li>
</ul>

<div class="warning">
    <h3>Consequences for Violations</h3>
    <p>By using CampusLink, you agree to follow these Community Guidelines. Violations may result in:</p>
    <ul>
        <li>Content removal</li>
        <li>Temporary account suspension</li>
        <li>Permanent account removal from the platform</li>
        <li>Reporting to university administration</li>
        <li>Reporting to law enforcement (for illegal activities)</li>
    </ul>
</div>

<div class="contact-box">
    <h2>Reporting Violations</h2>
    <p>If you see content or behavior that violates these guidelines, please report it immediately using the in-app reporting feature or by contacting us at:</p>
    <p>
        <strong>Email:</strong> <a href="mailto:support@campuslink.app">support@campuslink.app</a><br>
        <strong>Subject Line:</strong> Community Guidelines Violation
    </p>
    <p>We review all reports and take appropriate action to maintain a safe, respectful community for everyone.</p>
</div>

<p style="text-align: center; margin-top: 40px; opacity: 0.7;">
    Thank you for being a responsible member of the CampusLink community!
</p>
`;

const DOCUMENT_CONTENT: Record<DocumentType, string> = {
  terms: TERMS_CONTENT,
  privacy: PRIVACY_CONTENT,
  community: COMMUNITY_CONTENT,
};

// Generate PDF viewer HTML using PDF.js CDN
const generatePdfViewerHtml = (pdfBase64: string, colors: any): string => {
  return `
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <script src="https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.min.js"></script>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { 
      background-color: ${colors.background}; 
      padding: 0;
      overflow-x: hidden;
    }
    #pdf-container {
      display: flex;
      flex-direction: column;
      align-items: center;
      padding: 16px;
      padding-bottom: 80px;
    }
    canvas {
      max-width: 100%;
      margin-bottom: 16px;
      box-shadow: 0 2px 8px rgba(0,0,0,0.1);
    }
    .loading {
      color: ${colors.textSecondary};
      padding: 40px;
      text-align: center;
      font-family: -apple-system, BlinkMacSystemFont, sans-serif;
    }
    .error {
      color: ${colors.error || '#ff0000'};
      padding: 40px;
      text-align: center;
      font-family: -apple-system, BlinkMacSystemFont, sans-serif;
    }
  </style>
</head>
<body>
  <div id="pdf-container">
    <div class="loading">Loading document...</div>
  </div>
  <script>
    pdfjsLib.GlobalWorkerOptions.workerSrc = 'https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.worker.min.js';
    
    async function renderPdf() {
      const container = document.getElementById('pdf-container');
      try {
        const pdfData = atob('${pdfBase64}');
        const loadingTask = pdfjsLib.getDocument({ data: pdfData });
        const pdf = await loadingTask.promise;
        
        container.innerHTML = '';
        
        for (let pageNum = 1; pageNum <= pdf.numPages; pageNum++) {
          const page = await pdf.getPage(pageNum);
          const scale = (window.innerWidth - 32) / page.getViewport({ scale: 1 }).width;
          const viewport = page.getViewport({ scale: Math.min(scale, 2) });
          
          const canvas = document.createElement('canvas');
          const context = canvas.getContext('2d');
          canvas.height = viewport.height;
          canvas.width = viewport.width;
          
          await page.render({ canvasContext: context, viewport: viewport }).promise;
          container.appendChild(canvas);
        }
      } catch (error) {
        container.innerHTML = '<div class="error">Error loading document. Please try again.</div>';
        console.error(error);
      }
    }
    
    renderPdf();
  </script>
</body>
</html>
`;
};

const LegalDocumentScreen: React.FC = () => {
  const navigation = useNavigation();
  const route = useRoute<RouteProp<LegalDocumentRouteParams, 'LegalDocument'>>();
  const colors = useColors();
  const { documentType } = route.params;
  
  const [loading, setLoading] = useState(true);
  const [pdfBase64, setPdfBase64] = useState<string | null>(null);
  const [usePdf, setUsePdf] = useState(false);

  const title = DOCUMENT_TITLES[documentType];

  // Try to load PDF first, fall back to HTML content
  useEffect(() => {
    const loadPdf = async () => {
      try {
        const pdfAsset = PDF_ASSETS[documentType];
        if (pdfAsset) {
          const asset = Asset.fromModule(pdfAsset);
          await asset.downloadAsync();
          
          if (asset.localUri) {
            const base64 = await FileSystem.readAsStringAsync(asset.localUri, {
              encoding: 'base64',
            });
            setPdfBase64(base64);
            setUsePdf(true);
          }
        }
      } catch (error) {
        console.log('PDF not available, using HTML fallback');
      } finally {
        setLoading(false);
      }
    };

    loadPdf();
  }, [documentType]);

  const content = DOCUMENT_CONTENT[documentType];
  const htmlContent = usePdf && pdfBase64 
    ? generatePdfViewerHtml(pdfBase64, colors)
    : generateHtml(content, colors);

  return (
    <SafeAreaView style={[styles.container, { backgroundColor: colors.background }]} edges={['top', 'bottom']}>
      {/* Header */}
      <View style={[styles.header, { borderBottomColor: colors.border }]}>
        <TouchableOpacity onPress={() => navigation.goBack()} style={styles.backButton}>
          <Ionicons name="chevron-back" size={28} color={colors.primary} />
        </TouchableOpacity>
        <Text style={[styles.headerTitle, { color: colors.textPrimary }]}>{title}</Text>
        <View style={{ width: 28 }} />
      </View>

      {/* Content */}
      {loading ? (
        <View style={styles.loadingContainer}>
          <ActivityIndicator size="large" color={colors.primary} />
        </View>
      ) : (
        <WebView
          source={{ html: htmlContent }}
          style={styles.webView}
          originWhitelist={['*']}
          scrollEnabled={true}
          showsVerticalScrollIndicator={true}
          showsHorizontalScrollIndicator={false}
          scalesPageToFit={false}
          javaScriptEnabled={true}
          domStorageEnabled={true}
          startInLoadingState={true}
          renderLoading={() => (
            <View style={[styles.loadingContainer, { backgroundColor: colors.background }]}>
              <ActivityIndicator size="large" color={colors.primary} />
            </View>
          )}
          onError={(syntheticEvent) => {
            console.warn('WebView error:', syntheticEvent.nativeEvent);
          }}
          // Improve scrolling on iOS
          bounces={true}
          decelerationRate="normal"
          // Allow content to expand properly
          contentInset={{ top: 0, left: 0, bottom: 0, right: 0 }}
          automaticallyAdjustContentInsets={false}
        />
      )}
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
    paddingVertical: 12,
    borderBottomWidth: 1,
  },
  backButton: {
    padding: 4,
  },
  headerTitle: {
    fontSize: 18,
    fontWeight: '600',
  },
  webView: {
    flex: 1,
    backgroundColor: 'transparent',
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
});

export default LegalDocumentScreen;

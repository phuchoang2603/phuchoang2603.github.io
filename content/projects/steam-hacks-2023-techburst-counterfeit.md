---
title: TechBurst – Revolutionary AI Solution for Identifying Counterfeit Products
date: 2023-10-20
description:
tags:
  - figma
  - hackathon
  - flutter
draft: false
layout: "zen"
featureimage: https://i.ibb.co/KjcCfpzF/image.png
---
This is my product when participating in the STEAM Hacks 2023 competition. If you’re interested in delving deeper into the backstory and my journey throughout the competition, you can find the comprehensive details right here.
{{< article link="/posts/hackathon-steam-hacks-2023/" showSummary=true compactSummary=true >}}

## Overview of the main application
### 1. Current features:
- [x] C2C marketplace
- [x] Detection of fake and real products using the Teachable Machine scanner
- [x] Barcode scanner & NLP Instruction
### 2. Planned features:
- [ ] View sellers’ and buyers’ locations via Google Maps
- [ ] Bidding Algorithm
- [ ] Forecasting product demand and price changes (e.g. beecost…)
- [ ] Image tagging and recognition for product images
- [ ] Search for products using NLP queries and provide recommendations
- [ ] Assess product quality based on images, reviews, descriptions, etc.
- [ ] Allow users to train or utilize the categorization model.

https://github.com/phuchoang2603/techburst-counterfeit

## Simplifying Counterfeit Product Verification: A Journey of Implementing User-Friendly Solutions
In an era where counterfeit products flood the market, safeguarding consumers from purchasing fraudulent items has become a pressing concern. As an individual passionate about leveraging technology to combat this issue, my recent venture involved implementing an application that enables users to easily verify the authenticity of products. The process, although challenging, led to the development of a robust solution that empowers users to make informed purchasing decisions.

![](https://i.imgur.com/BNKxUR3.png)
*Image from ipcloseup.com*

## Exploring the Implementation Process
During the initial stages, I explored various potential implementations, each presenting its own set of hurdles. I want to make an Android application which have the Computer Vision feature on it. Initially, I came up with the idea of hosting a *.Tflite* model offline using Android Studio, which seemed [promising](https://www.youtube.com/watch?v=G0h5DAcvz6U), but the dependency management and debugging complexities proved daunting. Despite investing countless hours to resolve library errors, achieving a successful attempt remained elusive. Similarly, attempting to host a *Transformer* model on HuggingFace appeared overly complex, demanding a deep understanding of Transformer and Tensorflow intricacies.

However, the breakthrough emerged with the decision to develop a Flask backend for a REST API server, specifically tailored to handle Teachable Machine exported models. This decision, inspired by a helpful tutorial I stumbled upon, paved the way for a more feasible and practical approach.

Link of the tutorial: https://sogalanbat.medium.com/custom-api-for-keras-model-using-cloud-run-9d367a2ea5e8

## Overcoming Challenges and Constraints
Finding a way to accomplish my goal was a challenge, but I persevered. However, when the time came to put my plan into action, I realized it was much more difficult than anticipated. At the outset, my lack of prior knowledge in Machine Learning Model and Python Flask REST API posed a steep learning curve. Existing tutorials primarily focused on deploying entire Flask web apps or Tensorflow models, which didn't directly address the Teachable Machine's unique requirements.

Furthermore, wrestling with outdated Python packages presented a considerable setback. Efforts to convert image URLs directly to tensor files proved unreliable, often yielding inaccurate results due to the limitations in handling diverse image file types. However, persistence and patience ultimately led me to discover a workaround. I learned how to download image URLs directly and convert them to the compatible Keras format, effectively resolving the earlier challenges.

The deployment phase, while initially daunting, became more manageable with the aid of a comprehensible Dockerfile tutorial. Thanks to this newfound understanding, I successfully deployed the application on Google Cloud Platform (GCP). 

## Existing Limitations and Strategies for Optimization

{{< raw >}}
  <div>
<iframe width="100%" height="480"  src="https://www.youtube.com/embed/saBv1Hr-ffc" title="techburst-test" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>
  </div>
{{< /raw >}}

Despite the successful implementation, certain limitations persist. The machine learning model's inability to recognize products with 100% accuracy remains a challenge. Additionally, scaling the model to encompass a wider range of products proves challenging due to constraints in data resources.

![](https://i.imgur.com/xXAIIlM.png)
*The application cannot detect these physical patterns on real and fake products.*

![](https://i.imgur.com/lehaRi2.png)
*Although it achieved a 70% success rate after conducting 400 tests, relying solely on this mechanism may not be deemed reliable.*

To address these limitations and optimize the user experience, a novel approach has been conceived. Instead of relying solely on the machine learning model to identify differences between fake and authentic products, the application will facilitate user interaction with informative content. Users will receive guidance on how to physically examine the product, potentially by scanning barcodes or utilizing Optical Character Recognition (OCR) to decipher product numbers. The extracted data will then be passed through ChatGPT (LangChain) to source relevant internet pages based on credibility and popularity. A summarized report will then be relayed back to the user, empowering them to make informed decisions.

Here's a video demonstration of the app.

{{< raw >}}
  <div>
<iframe width="100%" height="480"  src="https://www.youtube.com/embed/A47P2lWPlN4" title="Techburst Demo" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>
  </div>
{{< /raw >}}

## The Journey Continues
As the application evolves, the aim remains to refine the user experience and enhance the application's capabilities. By continually addressing limitations and leveraging cutting-edge technologies, the vision of creating a user-friendly and effective counterfeit product verification solution inches closer to reality. Through perseverance and innovation, the battle against counterfeit products can be better equipped, allowing consumers to shop with confidence and trust.
